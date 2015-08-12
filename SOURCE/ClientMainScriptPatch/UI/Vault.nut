require("UI/ActionContainer");
require("UI/Equipment");
require("UI/Screens");
class Screens.Vault extends GUI.BigFrame
{
	static MAX_DELIVERY_SLOTS = 3;
	
	static mClassName = "Screens.Vault";
	
	mScreenContainer = null;
	mVaultContainer = null;
	mVaultContainerHolder = null;
	mColumns = 8;
	mRows = 15;
	mDeliveryColumns = 1;
	mDeliveryRows = 3;
	mMaxVaultSize = 120;
	mCurrentVaultSize = -1;
	mCurrentDeliveryBoxSlots = -1;
	mExpandVaultButton = null;
	mCurrentVaultId = -1;
	mDisabledSlotMaterial0 = "BG/ActionHolderPlug_64";
	mEnabledSlotMaterial0 = "BG/ActionHolder1_64";
	mEnabledSlotMaterial1 = "BG/ActionHolder2_64";
	mEnabledSlotMaterial2 = "BG/ActionHolder3_64";
	mNewsAndDeliveryHolder = null;
	mDeliveryBox = null;
	mDeliveryBoxAC = null;
	mNewsBox = null;
	mCheckDistanceEvent = null;
	mCheckPurchaseEvent = null;
	constructor()
	{
		GUI.BigFrame.constructor("Vault", true, {
			x = 373,
			y = 1
		});
		mScreenContainer = GUI.Container(GUI.BoxLayout());
		setPosition(400, 50);
		::_ItemDataManager.addListener(this);
		setContentPane(mScreenContainer);
		mScreenContainer.setInsets(5);
		::_Connection.addListener(this);
		mTitleBar.setAppearance("VaultTop");
		mContentPane.setAppearance("VaultSides");
		setCached(::Pref.get("video.UICache"));
	}

	function close()
	{
		setVisible(false);
	}

	function disableSlot( slot )
	{
		if (mVaultContainer)
		{
			mVaultContainer.setSlotsBackgroundMaterial(slot, mDisabledSlotMaterial0, true);
			mVaultContainer.setValidDropSlot(slot, false);
		}
	}

	function enableSlot( slot )
	{
		if (mVaultContainer)
		{
			local textureNum = slot % 3;
			local texture;

			if (textureNum == 0)
			{
				texture = mEnabledSlotMaterial0;
			}
			else if (textureNum == 1)
			{
				texture = mEnabledSlotMaterial1;
			}
			else
			{
				texture = mEnabledSlotMaterial2;
			}

			mVaultContainer.setSlotsBackgroundMaterial(slot, texture, true);
			mVaultContainer.setValidDropSlot(slot, true);
		}
	}

	function fitToScreen()
	{
		local pos = getPosition();
		pos.x = pos.x > 0 ? pos.x : 0;
		pos.y = pos.y > 0 ? pos.y : 0;
		pos.x = pos.x < ::Screen.getWidth() - getWidth() ? pos.x : ::Screen.getWidth() - getWidth();
		pos.y = pos.y < ::Screen.getHeight() - getHeight() ? pos.y : ::Screen.getHeight() - getHeight();
		setPosition(pos);
	}

	function getFreeSlotsRemaining()
	{
		return mCurrentVaultSize - mVaultContainer.getAllActionButtons().len();
	}

	function getMovable()
	{
		return mMovable;
	}

	function getActionContainer()
	{
		return mVaultContainer;
	}

	function onAcceptExpand( source, value )
	{
		if (value == "Proceed" && mExpandVaultButton)
		{
			mExpandVaultButton.setEnabled(false);
			::_Connection.sendQuery("vault.expand", this, [
				mCurrentVaultId
			]);
		}
	}
	function shouldActionButtonBeAdded( container, actionbuttonslot, actionbutton, action )
	{
		print("ICE! shouldActionButtonBeAdded( " + container + ","  + actionbuttonslot + "," + actionbutton + "," + action );
		print("ICE! vaultContainer = " + mVaultContainer + " / " +  mDeliveryBoxAC + " ac = " + actionbuttonslot.getActionContainer() + " prev : " + actionbutton.getPreviousActionContainer());
		//if (container == mVaultContainer && actionbuttonslot.getActionContainer() == mDeliveryBoxAC)
		//{
//			print("ICE! not adding because from delivery box, will remove instead");
			//return false;
		//}		
		return true;
	}

	function onActionButtonAdded( container, actionbuttonslot, actionbutton, action )
	{
		local disabled = false;

		if (container == mVaultContainer)
		{
			local itemdef = action._getItemDef();
			local profession = Professions[::_avatar.getStat(Stat.PROFESSION)].name;
			local avatarlevel = ::_avatar.getStat(Stat.LEVEL);

			if (itemdef && itemdef.getType() == ItemType.BASIC)
			{
				disabled = false;
			}
			else
			{
				local classrestrictions = itemdef.getClassRestrictions();

				if (avatarlevel < itemdef.getMinUseLevel())
				{
					disabled = true;
				}

				if (!classrestrictions[profession.tolower()])
				{
					disabled = true;
				}
			}
		}

		actionbuttonslot.setSlotDisabled(disabled);
		return true;
	}

	function onAttemptedItemDisown( actionContainer, action, slotIndex )
	{
		if (actionContainer == mVaultContainer)
		{
			local callback = {
				currAction = action,
				slotNum = slotIndex,
				currActionContainer = mVaultContainer,
				currentVaultId = mCurrentVaultId,
				function onActionSelected( mb, alt )
				{
					if (alt == "Yes")
					{
						if (_Connection)
						{
							_Connection.sendQuery("item.delete", this, [
								currAction.getItemId(),
								currentVaultId
							]);
							currActionContainer._removeActionButton(slotNum);
							_quickBarManager.removeItemFromQuickbar(currAction);
							local craftWindow = ::Screens.get("CraftingWindow", false);

							if (craftWindow)
							{
								craftWindow.onCraftReceipeRemove(currAction);
							}
						}
					}
				}

			};
			local def = action._getItemDef();

			if (def.getType() == ItemType.QUEST)
			{
				GUI.MessageBox.showYesNo("This item is used in the quest <font color=\"red\"><b>\"" + def.getQuestName() + "\"</b></font>.<br />Are you sure you want to destroy it?", callback);
			}
			else
			{
				GUI.MessageBox.showYesNo("This item will be destroyed.  Are you sure you want to destroy it? ", callback);
			}
		}
	}

	function onContainerUpdated( containerName, creatureId, container )
	{
		if (!container.hasAllItems())
		{
			return;
		}

		if (creatureId == ::_avatar.getID())
		{
			if (containerName == "bank")
			{
				if (mVaultContainer)
				{
					mVaultContainer.removeAllActions();

					foreach( itemId in container.mContents )
					{
						local item = ::_ItemManager.getItem(itemId);
						mVaultContainer.addAction(item, false, item.mItemData.mContainerSlot);
					}

					mVaultContainer.updateContainer();
				}
			}
			
			if(containerName == "deliveryBox")
			{
			}
		}
	}

	function onClosePressed()
	{
		close();
	}

	function onExpandVaultPressed( button )
	{
		GUI.MessageBox.showEx("You are about to expand your Vault by 8 slots. You will be charged 200 Credits.", [
			"Proceed",
			"Cancel"
		], this, "onAcceptExpand");
	}

	function onRightButtonReleased( actionButton, evt )
	{
		local abSlot = actionButton.getActionButtonSlot();
		
		print("ICE! ABslot " + slot);

		if (abSlot)
		{
			local actionContainer = abSlot.getActionContainer();
			print("ICE! Action container " + actionContainer);

			if (actionContainer == mDeliveryBoxAC)
			{
				local slotIndex = mDeliveryBoxAC.getIndexOfSlot(abSlot);
				print("ICE! Slot index  " + slotIndex);

				if (slotIndex != null)
				{
					slotIndex = slotIndex + (mDeliveryBoxAC.getCurrentPageNumber() - 1) * mDeliveryRows * mDeliveryColumns;
					::_Connection.sendQuery("vault.lootdeliveryitem", this, [
						mCurrentVaultId,
						slotIndex
					]);
					return false;
				}
			}
			else if (actionContainer == mVaultContainer)
			{
				print("ICE! VAult drop! ");
				if (Key.isDown(Key.VK_CONTROL))
				{
					local inventory = Screens.get("Inventory", true);

					if (inventory)
					{
						local freeslots = inventory.getFreeSlotsRemaining();

						if (freeslots > 0)
						{
							local inventoryAC = inventory.getMyActionContainer();
							inventoryAC.simulateButtonDrop(actionButton);
						}
					}
				}
			}
		}

		return true;
	}

	function onItemDefUpdated( itemDefId, itemdef )
	{
		if (!::_avatar)
		{
			return;
		}

		local proff = ::_avatar.getStat(Stat.PROFESSION);

		if (proff == null)
		{
			return;
		}

		local profession = Professions[::_avatar.getStat(Stat.PROFESSION)].name;
		local avatarlevel = ::_avatar.getStat(Stat.LEVEL);
		local visibleItemCount = mVaultContainer.getNumSlots();

		for( local i = 0; i < visibleItemCount; i++ )
		{
			local actionButtonSlot = mVaultContainer.getSlotContents(i);

			if (actionButtonSlot)
			{
				local actionButton = actionButtonSlot.getActionButton();

				if (actionButton)
				{
					local action = actionButton.getAction();
					local disabled = false;
					local itemdef = action._getItemDef();

					if (itemdef == itemdef)
					{
						if (itemdef && itemdef.getType() == ItemType.BASIC)
						{
							disabled = false;
						}
						else
						{
							local classrestrictions = itemdef.getClassRestrictions();

							if (avatarlevel < itemdef.getMinUseLevel())
							{
								disabled = true;
							}

							if (!classrestrictions[profession.tolower()])
							{
								disabled = true;
							}
						}

						actionButtonSlot.setSlotDisabled(disabled);
					}
				}
			}
		}
	}

	function onItemMovedInContainer( container, slotIndex, oldSlotsButton )
	{
		print("ICE! onItemMovedInContainer " + container + " slot " + slotIndex + " os: " + oldSlotsButton);
		local item = container.getSlotContents(slotIndex);
		local itemID = item.getActionButton().getAction().mItemId;
		local queryArgument = [];
		local previousSlotContainer = oldSlotsButton.getPreviousActionContainer();
		local oldActionButtonSlot = oldSlotsButton.getActionButtonSlot();
		local oldSlotContainerName = "";
		local oldSlotIndex = 0;

		if (previousSlotContainer && oldActionButtonSlot)
		{
			oldSlotContainerName = previousSlotContainer.getContainerName();
			oldSlotIndex = previousSlotContainer.getIndexOfSlot(oldActionButtonSlot);
		}
		
		if(container == mDeliveryBoxAC) 
		{
			::_Connection.sendQuery("vault.lootdeliveryitem", this, [
				mCurrentVaultId,
				oldSlotIndex
			]);
		}

		if (container == mVaultContainer)
		{
			if (item.getSwapped() == true)
			{
				item.setSwapped(false);
			}
			else
			{
				queryArgument.append(itemID);
				queryArgument.append("bank");
				queryArgument.append(slotIndex);

				if (::_Connection.getProtocolVersionId() >= 19)
				{
					queryArgument.append(oldSlotContainerName);
					queryArgument.append(oldSlotIndex);
				}

				queryArgument.append(::_avatar.getID());
				queryArgument.append(mCurrentVaultId);
				_Connection.sendQuery("item.move", this, queryArgument);
			}
		}
	}

	function onLevelUpdate( level )
	{
		if (!::_avatar)
		{
			return;
		}

		local proff = ::_avatar.getStat(Stat.PROFESSION);

		if (proff == null)
		{
			return;
		}

		local profession = Professions[proff].name;
		local avatarlevel = ::_avatar.getStat(Stat.LEVEL);
		local visibleItemCount = mVaultContainer.getNumSlots();

		for( local i = 0; i < visibleItemCount; i++ )
		{
			local actionButtonSlot = mVaultContainer.getSlotContents(i);

			if (actionButtonSlot)
			{
				local actionButton = actionButtonSlot.getActionButton();

				if (actionButton)
				{
					local action = actionButton.getAction();
					local disabled = false;
					local itemdef = action._getItemDef();

					if (itemdef && itemdef.getType() == ItemType.BASIC)
					{
						disabled = false;
					}
					else
					{
						local classrestrictions = itemdef.getClassRestrictions();

						if (avatarlevel < itemdef.getMinUseLevel())
						{
							disabled = true;
						}

						if (!classrestrictions[profession.tolower()])
						{
							disabled = true;
						}
					}

					actionButtonSlot.setSlotDisabled(disabled);
				}
			}
		}
	}

	function onQueryComplete( qa, rows )
	{
		switch(qa.query)
		{
		case "vault.expand":
			mCheckPurchaseEvent = ::_eventScheduler.fireIn(2.0, this, "_delayVaultButtonValid");
			break;

		case "vault.size":
			mCurrentVaultSize = rows[0][0].tointeger();
			mCurrentDeliveryBoxSlots = rows[0][1].tointeger();
			print("ICE! Delivery rows : " + rows[0][1].tointeger());
			_buildNewsAndDelivery();
			_buildVault();
			refreshVault();
			local ndSize = mNewsAndDeliveryHolder.getSize();
			local vaultSize = mVaultContainerHolder.getSize();
			setSize(ndSize.width + vaultSize.width + 8, ndSize.height + 32);
			setPreferredSize(ndSize.width + vaultSize.width + 8, ndSize.height + 32);
			mScreenContainer.setSize(ndSize.width + vaultSize.width, ndSize.height);
			mScreenContainer.setPreferredSize(ndSize.width + vaultSize.width, ndSize.height);
			::_Connection.sendQuery("vault.deliverycontents", this, [
				mCurrentVaultId
			]);
			GUI.Frame.setVisible(true);
			break;

		case "vault.deliverycontents":
		
			print("ICE! Vault delivery contents " + rows.len());
			for( local i = 0; i < rows.len(); i++ )
			{
				mDeliveryBoxAC.addAction(ItemProtoAction(rows[i][0]), false);
			}
			_checkDeliveryBoxes();

			break;

		case "vault.lootdeliveryitem":
			if (rows[0][0] == "OK")
			{
				print("ICE! Vault delivery item" + qa.args[1]);
				local slotIndex = qa.args[1];
				mDeliveryBoxAC.removeActionInSlot(slotIndex);
			}

			break;
		case "vault.removedeliveryitem":
			break;
		}
	}

	function onQueryError( qa, error )
	{
		IGIS.error(error);

		switch(qa.query)
		{
		case "item.move":
			::Util.handleMoveItemBack(qa);
			break;

		case "vault.size":
			break;

		case "vault.expand":
			mCheckPurchaseEvent = ::_eventScheduler.fireIn(2.0, this, "_delayVaultButtonValid");
			break;
		case "vault.lootdeliveryitem":
			mDeliveryBoxAC.removeAllActions();
			::_Connection.sendQuery("vault.deliverycontents", this, [
				mCurrentVaultId
			]);
			break;
		}
	}

	function _delayVaultButtonValid()
	{
		if (mCheckPurchaseEvent)
		{
			::_eventScheduler.cancel(mCheckPurchaseEvent);
		}

		if (mExpandVaultButton)
		{
			mExpandVaultButton.setEnabled(true);
		}
	}

	function onValidDropSlot( newSlot, oldSlot )
	{
		local oldActionContainer = oldSlot.getActionContainer();

		if (!oldActionContainer)
		{
			return false;
		}

		local newActionContainer = newSlot.getActionContainer();

		if (!newActionContainer)
		{
			return false;
		}

		if (::_avatar && ::_avatar.isDead())
		{
			IGIS.error("You cannot move items when you are dead.");
			return false;
		}
	}
	
	function onActionButtonLost( source, slot )
	{
		print("ICE! onActionButtonLost " + slot);
		local slotIndex = mDeliveryBoxAC.getIndexOfSlot(slot);
		if(slotIndex >= 0) {
			print("ICE! onActionButtonLost IDX " + slotIndex);
			::_Connection.sendQuery("vault.removedeliveryitem", this, [
				mCurrentVaultId,
				slotIndex
			]);
		}
	}	

	function refreshVault()
	{
		local vault = ::_ItemDataManager.getContents("bank");
		local bags = ::_ItemDataManager.getContents("eq");
		onContainerUpdated("bank", ::_avatar.getID(), vault);
		onContainerUpdated("eq", ::_avatar.getID(), bags);
	}

	function setContainerMoveProperties()
	{
		mVaultContainer.addMovingToProperties("inventory", MoveToProperties(MovementTypes.MOVE));
		mVaultContainer.addMovingToProperties("vault", MoveToProperties(MovementTypes.MOVE));
		mVaultContainer.addMovingToProperties("deliveryBox", MoveToProperties(MovementTypes.CLONE));
		mVaultContainer.addAcceptingFromProperties("inventory", AcceptFromProperties(this));
		mVaultContainer.addAcceptingFromProperties("vault", AcceptFromProperties(this));
		mVaultContainer.addAcceptingFromProperties("deliveryBox", AcceptFromProperties(this));
		
		mDeliveryBoxAC.addMovingToProperties("inventory", MoveToProperties(MovementTypes.MOVE));
		//mDeliveryBoxAC.addMovingToProperties("deliveryBox", MoveToProperties(MovementTypes.MOVE));
		mDeliveryBoxAC.addMovingToProperties("vault", MoveToProperties(MovementTypes.DESTROY, this));
		//mDeliveryBoxAC.addAcceptingFromProperties("inventory", AcceptFromProperties(this));
		mDeliveryBoxAC.addAcceptingFromProperties("vault", AcceptFromProperties(this));
		//mDeliveryBoxAC.addAcceptingFromProperties("deliveryBox", AcceptFromProperties(this));
		
		
	}
	
	function setDeliveryBoxSlots(newDeliveryBoxSlots) {
		mCurrentDeliveryBoxSlots = newDeliveryBoxSlots;
		_checkDeliveryBoxes();
	}

	function setVaultSize( newVaultSize )
	{
		for( local i = mCurrentVaultSize; i < newVaultSize; i++ )
		{
			enableSlot(i);
		}

		mCurrentVaultSize = newVaultSize;

		if (mCurrentVaultSize >= mMaxVaultSize)
		{
			if (mExpandVaultButton)
			{
				mVaultContainerHolder.remove(mExpandVaultButton);
				local vaultSize = mVaultContainerHolder.getSize();
				local buttonSize = mExpandVaultButton.getSize();
				mVaultContainerHolder.setSize(vaultSize.width + 4, vaultSize.height - buttonSize.height);
				mVaultContainerHolder.setPreferredSize(vaultSize.width + 4, vaultSize.height - buttonSize.height);
				mExpandVaultButton.destroy();
				mExpandVaultButton = null;
			}
		}
	}

	function setVaultId( id )
	{
		mCurrentVaultId = id;
	}

	function setVisible( visible )
	{
		if (visible)
		{
			::Audio.playSound("Sound-InventoryOpen.ogg");

			if (mCurrentVaultSize == -1)
			{
				::_Connection.sendQuery("vault.size", this, [
					mCurrentVaultId
				]);
			}
			else
			{
				GUI.Frame.setVisible(true);
				mDeliveryBoxAC.removeAllActions();
				::_Connection.sendQuery("vault.deliverycontents", this, [
					mCurrentVaultId
				]);
			}

			if (!mCheckDistanceEvent)
			{
				mCheckDistanceEvent = ::_eventScheduler.fireIn(0.5, this, "vaultDistanceCheck");
			}

			mCheckDistanceEvent = ::_eventScheduler.fireIn(0.5, this, "vaultDistanceCheck");
		}
		else
		{
			mCurrentVaultId = -1;
			GUI.Frame.setVisible(false);
			::Audio.playSound("Sound-InventoryClose.ogg");

			if (mCheckDistanceEvent)
			{
				::_eventScheduler.cancel(mCheckDistanceEvent);
				mCheckDistanceEvent = null;
			}
		}
	}

	function vaultDistanceCheck()
	{
		if (!isVisible())
		{
			return;
		}

		local vault = ::_sceneObjectManager.getCreatureByID(mCurrentVaultId);

		if (vault)
		{
			if (Math.manhattanDistanceXZ(::_avatar.getPosition(), vault.getPosition()) > Util.getRangeOffset(_avatar, vault) + MAX_USE_DISTANCE)
			{
				IGIS.error("You are too far away from the vault to continue using it.");
				setVisible(false);
				mCurrentVaultId = -1;
			}
			else
			{
				mCheckDistanceEvent = ::_eventScheduler.fireIn(0.5, this, "vaultDistanceCheck");
			}
		}
		else
		{
			IGIS.error("This vault no longer exists.");
			setVisible(false);
			mCurrentVaultId = -1;
		}
	}

	function _addNotify()
	{
		GUI.ContainerFrame._addNotify();
	}

	function _buildVault()
	{
		mVaultContainerHolder = GUI.Container(GUI.BorderLayout());
		local titleBar = GUI.TitleBar(null, "Character Vault", false);
		titleBar.setAppearance("FrameTopBarSilver");
		mVaultContainer = GUI.ActionContainer("vault", mRows, mColumns, 0, 0, this, false);
		mVaultContainer.setUseMode(GUI.ActionButtonSlot.USE_LEFT_DOUBLE_CLICK);
		mVaultContainer.setCallback(this);
		mVaultContainer.setAllowButtonDisownership(false);
		local vaultPanel = GUI.Panel(GUI.BoxLayoutV());
		vaultPanel.add(mVaultContainer);
		vaultPanel.setAppearance("SilverBorder");
		mVaultContainerHolder.add(titleBar, GUI.BorderLayout.NORTH);
		mVaultContainerHolder.add(vaultPanel, GUI.BorderLayout.CENTER);
		local size = mVaultContainer.getPreferredSize();

		if (mCurrentVaultSize < mMaxVaultSize)
		{
			mExpandVaultButton = GUI.NarrowButton("Expand Vault");
			mExpandVaultButton.addActionListener(this);
			mExpandVaultButton.setReleaseMessage("onExpandVaultPressed");
			mVaultContainerHolder.add(mExpandVaultButton, GUI.BorderLayout.SOUTH);
			local buttonSize = mExpandVaultButton.getPreferredSize();
			size.height += buttonSize.height;
		}

		local titleBarSize = titleBar.getSize();
		size.height += titleBarSize.height;
		mVaultContainerHolder.setSize(size.width + 15, size.height + 42);
		mVaultContainerHolder.setPreferredSize(size.width + 15, size.height + 42);
		setContainerMoveProperties();
		mVaultContainer.addListener(this);
		mVaultContainer.setItemPanelVisible(false);
		mVaultContainer.setValidDropContainer(true);
		local vault = ::_ItemDataManager.getContents("bank");
		onContainerUpdated("bank", ::_avatar.getID(), vault);
		local i = 0;

		for( i = 0; i < mCurrentVaultSize; i++ )
		{
			enableSlot(i);
		}

		while (i < mMaxVaultSize)
		{
			disableSlot(i);
			i++;
		}

		mScreenContainer.add(mVaultContainerHolder);
	}
	
	function _resizeDelivery() 
	{
		local newsSize = mNewsBox.getSize();
		local deliverySize = mDeliveryBox.getSize();
		mNewsAndDeliveryHolder.setSize(newsSize.width, newsSize.height + deliverySize.height);
	}

	function _buildNewsAndDelivery()
	{
		mNewsAndDeliveryHolder = GUI.Container(GUI.BoxLayoutV());
		mNewsBox = _buildNewsBox();
		mDeliveryBox = _buildDeliveryBox();
		mNewsAndDeliveryHolder.add(mNewsBox);
		mNewsAndDeliveryHolder.add(mDeliveryBox);
		mScreenContainer.add(mNewsAndDeliveryHolder);
		_resizeDelivery();
	}

	function _buildNewsBox()
	{
		local newsBox = GUI.Panel();
		newsBox.setAppearance("VaultImage");
		newsBox.setSize(254, 315);
		newsBox.setPreferredSize(254, 315);
		return newsBox;
	}
	
	function _checkDeliveryBoxes() {
		print("ICE! checking delivery boxes from a total of " + mCurrentDeliveryBoxSlots + " boxes in " + MAX_DELIVERY_SLOTS);
		
		local pages = mCurrentDeliveryBoxSlots == 0 ? 0 : ( ( mCurrentDeliveryBoxSlots - 1 )  / 3) + 1;
		print("ICE! delivery pages = "  +pages);
		mDeliveryBoxAC.setMaxPages(pages);
		mDeliveryBoxAC.updateContainer();
		
		for(local i = 0 ; i < MAX_DELIVERY_SLOTS; i++) {
			if(i >= mCurrentDeliveryBoxSlots) {
				print("ICE! disabling delivery slot " + i);
				mDeliveryBoxAC.setValidDropSlot(i, false);
				mDeliveryBoxAC.setSlotsBackgroundMaterial(i, mDisabledSlotMaterial0, true);
			}
			else {			
				print("ICE! enabling delivery slot " + i);
				mDeliveryBoxAC.setValidDropSlot(i, true);
				mDeliveryBoxAC.setSlotsBackgroundMaterial(i, mEnabledSlotMaterial0, true);
			}	
		}

		mDeliveryBoxAC.updateContainer();
	}

	function _buildDeliveryBox()
	{
		local deliveryBox = GUI.Container(GUI.BorderLayout());
		local containerHolder = GUI.Panel(GUI.BoxLayoutV());
		containerHolder.setAppearance("SilverBorder");
		local titleBar = GUI.TitleBar(null, "Delivery Box", false);
		titleBar.setAppearance("FrameTopBarSilver");
		mDeliveryBoxAC = GUI.ActionContainer("deliveryBox", mDeliveryRows, mDeliveryColumns, 0, 0, this);
		mDeliveryBoxAC.setAllButtonsDraggable(true);
		mDeliveryBoxAC.setAllowButtonDisownership(true);
		mDeliveryBoxAC.setItemPanelVisible(true);
		mDeliveryBoxAC.addListener(this);
		mDeliveryBoxAC.setCallback(this);
		mDeliveryBoxAC.setTooltipRenderingModifiers("itemProto", {
			hideValue = true,
			resizeInfoPanel = false
		});
		containerHolder.add(mDeliveryBoxAC);
		deliveryBox.add(titleBar, GUI.BorderLayout.NORTH);
		deliveryBox.add(containerHolder, GUI.BorderLayout.CENTER);
		deliveryBox.setPreferredSize(250, 250);
		deliveryBox.setSize(250, 250);
		_checkDeliveryBoxes();
		return deliveryBox;
	}

	function _removeNotify()
	{
		close();
		GUI.ContainerFrame._removeNotify();
	}

}
