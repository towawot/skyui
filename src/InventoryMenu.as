﻿import gfx.io.GameDelegate;
import Shared.GlobalFunc;
import gfx.ui.NavigationCode;

import skyui.CategoryList;
import skyui.TabularList;
import skyui.InventoryEntryFormatter;
import skyui.InventoryDataFetcher;
import skyui.ListLayoutManager;


class InventoryMenu extends ItemMenu
{
	private var _bMenuClosing:Boolean;

	var EquipButtonArt:Object;
	var AltButtonArt:Object;
	var ChargeButtonArt:Object;
	var PrevButtonArt:Object;
	var ItemCardListButtonArt:Array;
	var CategoryListIconArt:Array;

	// ?
	var bPCControlsReady = true;


	function InventoryMenu()
	{
		super();
		
		_bMenuClosing = false;
		
		EquipButtonArt = {PCArt:"M1M2", XBoxArt:"360_LTRT", PS3Art:"PS3_LBRB"};
		AltButtonArt = {PCArt:"E", XBoxArt:"360_A", PS3Art:"PS3_A"};
		ChargeButtonArt = {PCArt:"T", XBoxArt:"360_RB", PS3Art:"PS3_RT"};
		ItemCardListButtonArt = [{PCArt:"Enter", XBoxArt:"360_A", PS3Art:"PS3_A"},
								 {PCArt:"Tab", XBoxArt:"360_B", PS3Art:"PS3_B"}];
		PrevButtonArt = undefined;
		
		CategoryListIconArt = ["cat_favorites", "inv_all", "inv_weapons", "inv_armor",
							   "inv_potions", "inv_scrolls", "inv_food", "inv_ingredients",
							   "inv_books", "inv_keys", "inv_misc"];
		
		GameDelegate.addCallBack("AttemptEquip", this, "AttemptEquip");
		GameDelegate.addCallBack("DropItem", this, "DropItem");
		GameDelegate.addCallBack("AttemptChargeItem", this, "AttemptChargeItem");
		GameDelegate.addCallBack("ItemRotating", this, "ItemRotating");
	}

	function InitExtensions()
	{
		super.InitExtensions();

		GlobalFunc.AddReverseFunctions();
		inventoryLists.zoomButtonHolder.gotoAndStop(1);
		BottomBar_mc.SetButtonArt(ChargeButtonArt, 3);
	
		// Initialize menu-specific list components
		var categoryList: CategoryList = inventoryLists.categoryList;
		categoryList.iconArt = CategoryListIconArt;
		
		var itemList: TabularList = inventoryLists.itemList;		
		var entryFormatter = new InventoryEntryFormatter(itemList);
		entryFormatter.maxTextLength = 80;
		itemList.entryFormatter = entryFormatter;
		itemList.dataFetcher = new InventoryDataFetcher();
		itemList.layout = ListLayoutManager.instance.getLayoutByName("ItemListLayout");

		ItemCard_mc.addEventListener("itemPress", this, "onItemCardListPress");
	}

	function handleInput(details, pathToFocus)
	{
		if (bFadedIn && !pathToFocus[0].handleInput(details, pathToFocus.slice(1))) {
			if (GlobalFunc.IsKeyPressed(details)) {
				if (details.navEquivalent == NavigationCode.TAB) {
					StartMenuFade();
					GameDelegate.call("CloseTweenMenu", []);
				}
			} else if (!inventoryLists.itemList.disableInput) {
				if (details.navEquivalent == NavigationCode.GAMEPAD_BACK && details.code != 8 && _platform != 0) {
					openMagicMenu();
				}
			}
		}
		
		return true;
	}
	
	// currently only used for controller users when pressing the BACK button
	function openMagicMenu()
	{
			SaveIndices();
			GameDelegate.call("CloseMenu",[]);
			GameDelegate.call("CloseTweenMenu",[]);
			skse.OpenMenu("Magic Menu");
	}

	function onExitMenuRectClick()
	{
		StartMenuFade();
		GameDelegate.call("ShowTweenMenu", []);
	}

	function StartMenuFade()
	{
		inventoryLists.hideCategoriesList();
		ToggleMenuFade();
		SaveIndices();
		_bMenuClosing = true;
	}

	function onFadeCompletion()
	{
		if (_bMenuClosing) {
			GameDelegate.call("CloseMenu", []);
		}
	}

	function onShowItemsList(event)
	{
		super.onShowItemsList(event);
		if (event.index != -1) {
			UpdateBottomBarButtons();
		}
	}

	function onItemHighlightChange(event)
	{
		super.onItemHighlightChange(event);
		if (event.index != -1) {
			UpdateBottomBarButtons();
			
		}
	}

	function UpdateBottomBarButtons()
	{
		BottomBar_mc.SetButtonArt(AltButtonArt, 0);
		switch (ItemCard_mc.itemInfo.type) {
			case InventoryDefines.ICT_ARMOR :
				BottomBar_mc.SetButtonText("$Equip", 0);
				break;

			case InventoryDefines.ICT_BOOK :
				BottomBar_mc.SetButtonText("$Read", 0);
				break;

			case InventoryDefines.ICT_POTION :
				BottomBar_mc.SetButtonText("$Use", 0);
				break;

			case InventoryDefines.ICT_FOOD :
			case InventoryDefines.ICT_INGREDIENT :
				BottomBar_mc.SetButtonText("$Eat", 0);
				break;

			default :
				BottomBar_mc.SetButtonArt(EquipButtonArt, 0);
				BottomBar_mc.SetButtonText("$Equip", 0);
		}


		BottomBar_mc.SetButtonText("$Drop", 1);
		if (inventoryLists.itemList.selectedEntry.filterFlag & inventoryLists.categoryList.entryList[0].flag != 0) {
			BottomBar_mc.SetButtonText("$Unfavorite", 2);
		} else {
			BottomBar_mc.SetButtonText("$Favorite", 2);
		}

		if (ItemCard_mc.itemInfo.charge != undefined && ItemCard_mc.itemInfo.charge < 100) {
			BottomBar_mc.SetButtonText("$Charge", 3);
		} else {
			BottomBar_mc.SetButtonText("", 3);
		}
	}

	function onHideItemsList(event)
	{
		super.onHideItemsList(event);
		BottomBar_mc.UpdatePerItemInfo({type:InventoryDefines.ICT_NONE});
	}

	function onItemSelect(event)
	{
		if (event.entry.enabled && event.keyboardOrMouse != 0) {
			GameDelegate.call("ItemSelect", []);
		}
	}

	function AttemptEquip(a_slot, a_bCheckOverList)
	{
		var bCheckOverList = a_bCheckOverList != undefined ? a_bCheckOverList : true;
		if (ShouldProcessItemsListInput(bCheckOverList) && ConfirmSelectedEntry()) {
			GameDelegate.call("ItemSelect", [a_slot]);
		}
	}

	function DropItem()
	{
		if (ShouldProcessItemsListInput(false) && inventoryLists.itemList.selectedEntry != undefined) {
			if (inventoryLists.itemList.selectedEntry.count <= InventoryDefines.QUANTITY_MENU_COUNT_LIMIT) {
				onQuantityMenuSelect({amount:1});
			} else {
				ItemCard_mc.ShowQuantityMenu(inventoryLists.itemList.selectedEntry.count);
			}
		}
	}

	function AttemptChargeItem()
	{
		if (inventoryLists.itemList.selectedIndex == -1) {
			return;
		}
		
		if (ShouldProcessItemsListInput(false) && ItemCard_mc.itemInfo.charge != undefined && ItemCard_mc.itemInfo.charge < 100) {
			GameDelegate.call("ShowSoulGemList", []);
		}
	}

	function onQuantityMenuSelect(event)
	{
		GameDelegate.call("ItemDrop", [event.amount]);
		
		// Bug Fix: ItemCard does not update when attempting to drop quest items through the quantity menu
		//   so let's request an update even though it may be redundant.
		GameDelegate.call("RequestItemCardInfo", [], this, "UpdateItemCardInfo");
	}

	function onMouseRotationFastClick(aiMouseButton)
	{
		GameDelegate.call("CheckForMouseEquip", [aiMouseButton], this, "AttemptEquip");
	}

	function onItemCardListPress(event)
	{
		GameDelegate.call("ItemCardListCallback", [event.index]);
	}

	function onItemCardSubMenuAction(event)
	{
		super.onItemCardSubMenuAction(event);
		GameDelegate.call("QuantitySliderOpen", [event.opening]);
		
		if (event.menu == "list") {
			if (event.opening == true) {
				PrevButtonArt = BottomBar_mc.GetButtonsArt();
				BottomBar_mc.SetButtonsText("$Select", "$Cancel");
				BottomBar_mc.SetButtonsArt(ItemCardListButtonArt);
			} else {
				BottomBar_mc.SetButtonsArt(PrevButtonArt);
				PrevButtonArt = undefined;
				GameDelegate.call("RequestItemCardInfo", [], this, "UpdateItemCardInfo");
				UpdateBottomBarButtons();
			}
		}
	}

	function SetPlatform(a_platform, a_bPS3Switch)
	{
		inventoryLists.zoomButtonHolder.gotoAndStop(1);
		inventoryLists.zoomButtonHolder.ZoomButton._visible = a_platform != 0;
		inventoryLists.zoomButtonHolder.ZoomButton.SetPlatform(a_platform, a_bPS3Switch);
		super.SetPlatform(a_platform, a_bPS3Switch);
	}

	function ItemRotating()
	{
		inventoryLists.zoomButtonHolder.PlayForward(inventoryLists.zoomButtonHolder._currentframe);
	}
}