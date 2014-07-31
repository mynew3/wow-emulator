-module(item).

-export([swap/3]).
-export([create/2]).
-export([equip_new/3, equip_new/4, equip/5, equip/6]).
-export([init_char_slot_values/0]).
-export([get_item_guids/1, get_equipped_item_guids/1]).
-export([slot_empty/2, get_item_guid_at_slot/2]).

-compile([export_all]).

-include("include/types.hrl").
-include("include/binary.hrl").
-include("include/database_records.hrl").
-include("include/character.hrl").
-include("include/items.hrl").
-include("include/shared_defines.hrl").



swap(SrcSlot, DestSlot, Guid) ->
	SrcEmpty = slot_empty(SrcSlot, Guid),
	DestEmpty = slot_empty(DestSlot, Guid),
	SrcIsValidSlot = is_valid_slot(SrcSlot),
	DestIsValidSlot = is_valid_slot(DestSlot),

	DestIsInvSlot = is_inv_slot(DestSlot),
	DestIsEquipSlot = is_equip_slot(DestSlot),


	if SrcEmpty ->
			{error, ?equip_err_slot_is_empty};
		SrcSlot == DestSlot ->
			{error, ?equip_err_items_cant_be_swapped};
		not SrcIsValidSlot orelse not DestIsValidSlot ->
			{error, ?equip_err_no_equipment_slot_available};
		DestEmpty ->
			if DestIsInvSlot ->
				store_from_slot(SrcSlot, DestSlot, Guid);
				DestIsEquipSlot ->

					CanEquipSrcAtDest = can_equip_from_slot(SrcSlot, DestSlot, Guid),

					if CanEquipSrcAtDest ->
							equip_from_slot(SrcSlot, DestSlot, Guid);
						not CanEquipSrcAtDest ->
							{error, ?equip_err_item_doesnt_go_to_slot}
					end
			end;

		not DestEmpty ->

			CanSwap = can_swap(SrcSlot, DestSlot, Guid),

			if DestIsInvSlot ->

				CanMerge = can_merge(SrcSlot, DestSlot, Guid),
				CanMergeWithOverFlow = can_merge_with_overflow(SrcSlot, DestSlot, Guid),

				if CanMerge ->
						merge(SrcSlot, DestSlot, Guid);
					CanMergeWithOverFlow ->
						merge_with_overflow(SrcSlot, DestSlot, Guid);
					CanSwap ->
						swap_slots(SrcSlot, DestSlot, Guid);
					not CanSwap ->
						{error, ?equip_err_items_cant_be_swapped}
				end;
				DestIsEquipSlot ->

					if CanSwap ->
							swap_slots(SrcSlot, DestSlot, Guid);
						not CanSwap ->
							{error, ?equip_err_items_cant_be_swapped}
					end
			end

	end.


can_merge(SrcSlot, DestSlot, Guid) ->
	SrcItemGuid = get_item_guid_at_slot(SrcSlot, Guid),
	DestItemGuid = get_item_guid_at_slot(DestSlot, Guid),

	SrcItemProto = item_data:get_item_proto(SrcItemGuid),
	DestItemProto = item_data:get_item_proto(DestItemGuid),

	% check if they are the same item and that item is stackable
	StackSize = SrcItemProto#item_proto.stackable,
	if SrcItemProto#item_proto.id == DestItemProto#item_proto.id andalso StackSize > 1 ->
			SrcItemValues = item_data:get_values(SrcItemGuid),
			DestItemValues = item_data:get_values(DestItemGuid),
			SrcStackCount = item_values:get_stack_count(SrcItemValues),
			DestStackCount = item_values:get_stack_count(DestItemValues),
			TotalAmount = SrcStackCount + DestStackCount,
			if TotalAmount =< StackSize -> true;
				% handle overflow in separate case
				TotalAmount > StackSize -> false
			end;
		true -> false
	end.

can_merge_with_overflow(SrcSlot, DestSlot, Guid) ->
	false.

merge(SrcSlot, DestSlot, Guid) ->
	SrcItemGuid = get_item_guid_at_slot(SrcSlot, Guid),
	DestItemGuid = get_item_guid_at_slot(DestSlot, Guid),

	SrcItemValues = item_data:get_values(SrcItemGuid),
	DestItemValues = item_data:get_values(DestItemGuid),

	SrcStackCount = item_values:get_stack_count(SrcItemValues),
	DestStackCount = item_values:get_stack_count(DestItemValues),
	TotalAmount = SrcStackCount + DestStackCount,

	NewDestItemValues = item_values:set_stack_count(TotalAmount, DestItemValues),
	item_data:store_values(NewDestItemValues),

	NewSrcItemValues = item_values:set_stack_count(0, SrcItemValues),
	item_data:store_values(NewSrcItemValues),
	remove(SrcSlot, Guid),
	%todo how to delete an item?

	update_data:build_create_update_packet_for_items([SrcItemGuid, DestItemGuid]).

merge_with_overflow(SrcSlot, DestSlot, Guid) ->
	ok.


can_swap(SrcSlot, DestSlot, Guid) ->
	DestIsInvSlot = is_inv_slot(DestSlot),
	DestIsEquipSlot = is_equip_slot(DestSlot),

	SrcIsInvSlot = is_inv_slot(SrcSlot),
	SrcIsEquipSlot = is_equip_slot(SrcSlot),

	CanEquipSrcAtDest = can_equip_from_slot(SrcSlot, DestSlot, Guid),
	CanEquipDestAtSrc = can_equip_from_slot(DestSlot, SrcSlot, Guid),

	(DestIsInvSlot andalso SrcIsInvSlot) orelse
	(DestIsInvSlot andalso SrcIsEquipSlot andalso CanEquipDestAtSrc) orelse
	(DestIsEquipSlot andalso SrcIsInvSlot andalso CanEquipSrcAtDest) orelse
	(DestIsEquipSlot andalso SrcIsEquipSlot andalso CanEquipSrcAtDest andalso CanEquipDestAtSrc).



swap_slots(SrcSlot, DestSlot, Guid) ->
	SrcItemGuid = get_item_guid_at_slot(SrcSlot, Guid),
	DestItemGuid = get_item_guid_at_slot(DestSlot, Guid),

	DestIsInvSlot = is_inv_slot(DestSlot),
	DestIsEquipSlot = is_equip_slot(DestSlot),

	DestIsEquipSlot = is_equip_slot(DestSlot),
	SrcIsEquipSlot = is_equip_slot(SrcSlot),

	remove(SrcSlot, Guid),
	remove(DestSlot, Guid),

	equip_slot(SrcItemGuid, DestSlot, Guid),
	if DestIsEquipSlot ->
			visualize_item(Guid, SrcItemGuid, DestSlot, true);
		DestIsInvSlot -> ok
	end,

	equip_slot(DestItemGuid, SrcSlot, Guid),
	if SrcIsEquipSlot ->
			visualize_item(Guid, DestItemGuid, SrcSlot, true);
		DestIsInvSlot -> ok
	end,

	update_data:build_create_update_packet_for_items([SrcItemGuid, DestItemGuid]).


% remove from old slot
% store in inventory
store_from_slot(SrcSlot, DestSlot, Guid) ->
	ItemGuid = get_item_guid_at_slot(SrcSlot, Guid),
	remove(SrcSlot, Guid),
	equip(ItemGuid, DestSlot, Guid).

% remove from old slot
% equip item
equip_from_slot(SrcSlot, DestSlot, Guid) ->
	ItemGuid = get_item_guid_at_slot(SrcSlot, Guid),
	remove(SrcSlot, Guid),
	visualize_item(Guid, ItemGuid, DestSlot, true),
	equip(ItemGuid, DestSlot, Guid).


can_equip_from_slot(SrcSlot, DestSlot, Guid) ->
	ItemGuid = get_item_guid_at_slot(SrcSlot, Guid),
	can_equip(ItemGuid, DestSlot).

can_equip(ItemGuid, Slot) ->
	ItemProto = item_data:get_item_proto(ItemGuid),
	InvType = ItemProto#item_proto.inventory_type,
	EquipSlot = get_slot(InvType),
	Slot == EquipSlot.



remove(Slot, OwnerGuid) ->
	%ItemGuid = get_item_guid_at_slot(Slot, OwnerGuid),

	Values = char_data:get_values(OwnerGuid),
	NewValues = char_values:set_item(Slot, 0, Values, true),
	char_data:update_values(OwnerGuid, NewValues),

	SlotValues = char_data:get_slot_values(OwnerGuid),
	Offset = 8 * Slot,
	<<Head:Offset/binary, _ItemGuid?Q, Rest/binary>> = SlotValues,
	NewSlotValues = <<Head/binary, 0?Q, Rest/binary>>,
	char_data:update_slot_values(OwnerGuid, NewSlotValues),

	set_visual_item_slot(OwnerGuid, 0, Slot, true),
	ok.


is_valid_slot(Slot) ->
	is_inv_slot(Slot) orelse is_equip_slot(Slot).

% inside bag
is_inv_slot(Slot) ->
	Slot >= ?inventory_slot_item_start andalso Slot < ?inventory_slot_item_end.

is_equip_slot(Slot) ->
	Slot >= ?equipment_slot_start andalso Slot < ?equipment_slot_end.


slot_empty(Slot, Guid) ->
	SlotGuid = get_item_guid_at_slot(Slot, Guid),
	SlotGuid == 0.


get_item_guid_at_slot(Slot, Guid) ->
	SlotGuids = char_data:get_slot_values(Guid),
	Offset = 8 * Slot,
	<<_:Offset/binary, SlotGuid?Q, _/binary>> = SlotGuids,
	SlotGuid.







get_equipped_item_guids(Guid) ->
	ItemGuids = get_item_guids(Guid),
	{Guids, _} = lists:split(?equipment_slot_end, ItemGuids),
	Guids.

get_item_guids(Guid) ->
	SlotValues = char_data:get_slot_values(Guid),
	Guids = extract_slot_values_guids(SlotValues),
	lists:reverse(Guids).

extract_slot_values_guids(SlotValues) ->
	extract_slot_values_guids(SlotValues, []).
extract_slot_values_guids(<<>>, Acc) -> Acc;
extract_slot_values_guids(<<Guid?Q, Rest/binary>>, Acc) ->
	extract_slot_values_guids(Rest, [Guid|Acc]).




init_char_slot_values() ->
	binary:copy(<<0?Q>>, ?player_slots_count).


equip_item_at_slot(Slot, ItemGuid, OwnerGuid, MarkUpdate) ->
	SlotValues = char_data:get_slot_values(OwnerGuid),
	Offset = Slot * 8,
	<<Head:Offset/binary, _OldItemGuid?Q, Rest/binary>> = SlotValues,
	NewCharSlotValues = <<Head/binary, ItemGuid?Q, Rest/binary>>,
	char_data:update_slot_values(OwnerGuid, NewCharSlotValues),
	visualize_item(OwnerGuid, ItemGuid, Slot, MarkUpdate).



equip_new(ItemId, CharSlotValues, OwnerGuid) ->
	equip_new(ItemId, CharSlotValues, OwnerGuid, true).
equip_new(ItemId, CharSlotValues, OwnerGuid, MarkUpdate) ->
	ItemValues = create(ItemId, OwnerGuid),
	item_data:store_values(ItemValues),
	ItemGuid = item_values:get_guid(ItemValues),
	equip(OwnerGuid, ItemId, CharSlotValues, ItemGuid, false, MarkUpdate).


equip_slot(ItemGuid, DestSlot, OwnerGuid) ->
	SlotValues = char_data:get_slot_values(OwnerGuid),
	Offset = DestSlot * 8,
	<<Head:Offset/binary, _OldItemGuid?Q, Rest/binary>> = SlotValues,
	NewCharSlotValues = <<Head/binary, ItemGuid?Q, Rest/binary>>,
	char_data:update_slot_values(OwnerGuid, NewCharSlotValues),

	Values = char_data:get_values(OwnerGuid),
	NewValues = char_values:set_item(DestSlot, ItemGuid, Values, true),
	char_data:update_values(OwnerGuid, NewValues),

	ItemValues = item_data:get_values(ItemGuid),
	NewItemValues1 = item_values:set_owner(OwnerGuid, ItemValues),
	NewItemValues = item_values:set_contained(OwnerGuid, NewItemValues1),
	item_data:store_values(NewItemValues).

equip(ItemGuid, DestSlot, OwnerGuid) ->
	equip_slot(ItemGuid, DestSlot, OwnerGuid),
	update_data:build_create_update_packet_for_items([ItemGuid]).

equip(OwnerGuid, ItemId, SlotValues, NewItemGuid, Swap) ->
	equip(OwnerGuid, ItemId, SlotValues, NewItemGuid, Swap, true).
equip(OwnerGuid, ItemId, SlotValues, NewItemGuid, Swap, MarkUpdate) ->
	ItemProto = content:lookup_item(ItemId),
	Class = ItemProto#item_proto.class,
	if Class == ?item_class_weapon orelse Class == ?item_class_armor ->
		InvType = ItemProto#item_proto.inventory_type,
		Slot = get_slot(InvType),
		if Slot >= 0 ->
				% offset is in 64 bit chunks
				Offset = Slot * 8,
				<<_:Offset/binary, OldItemGuid?Q, _/binary>> = SlotValues,
				if OldItemGuid == 0 orelse Swap ->
						equip_item_at_slot(Slot, NewItemGuid, OwnerGuid, MarkUpdate),
						ok;
					true ->
						ok
				end;
			true -> ok
			end;
		true ->
				% put item in bag
				Values = char_data:get_values(OwnerGuid),
				Slot = get_first_empty_inv_slot(OwnerGuid),
				Offset = Slot * 8,
						<<Head:Offset/binary, _OldItemGuid?Q, Rest/binary>> = SlotValues,
						NewCharSlotValues = <<Head/binary, NewItemGuid?Q, Rest/binary>>,
						char_data:update_slot_values(OwnerGuid, NewCharSlotValues),
				NewValues = char_values:set_item(Slot, NewItemGuid, Values, MarkUpdate),
				char_data:update_values(OwnerGuid, NewValues),

				ItemValues = item_data:get_values(NewItemGuid),
				NewItemValues1 = item_values:set_owner(OwnerGuid, ItemValues),
				NewItemValues = item_values:set_contained(OwnerGuid, NewItemValues1),
				item_data:store_values(NewItemValues)

	end.

get_first_empty_inv_slot(OwnerGuid) ->
	FirstSlot = ?inventory_slot_item_start,
	Values = char_data:get_values(OwnerGuid),
	get_first_empty_inv_slot(Values, FirstSlot).

get_first_empty_inv_slot(_, ?inventory_slot_item_end) -> 0;
get_first_empty_inv_slot(Values, Slot) ->
	SlotValue = char_values:item(Slot, Values),
	if SlotValue == 0 -> Slot;
		SlotValue > 0 ->
			get_first_empty_inv_slot(Values, Slot + 1)
	end.

visualize_item(OwnerGuid, ItemGuid, Slot, MarkUpdate) ->
	Values = char_data:get_values(OwnerGuid),
	NewValues = char_values:set_item(Slot, ItemGuid, Values, MarkUpdate),
	char_data:update_values(OwnerGuid, NewValues),

	ItemValues = item_data:get_values(ItemGuid),
	NewItemValues1 = item_values:set_owner(OwnerGuid, ItemValues),
	NewItemValues = item_values:set_contained(OwnerGuid, NewItemValues1),
	item_data:store_values(NewItemValues),

	set_visual_item_slot(OwnerGuid, ItemGuid, Slot, MarkUpdate).


set_visual_item_slot(OwnerGuid, ItemGuid, Slot, MarkUpdate) ->
	Values = char_data:get_values(OwnerGuid),
	ItemId = if ItemGuid > 0 ->
			ItemValues = item_data:get_values(ItemGuid),
			item_values:get_item_id(ItemValues);
		true -> 0
	end,
	NewValues = char_values:set_visible_item(Slot, ItemId, Values, MarkUpdate),
	char_data:update_values(OwnerGuid, NewValues).



get_slot(InvType) ->
	case InvType of
		?invtype_head -> ?equipment_slot_head;
		?invtype_neck -> ?equipment_slot_neck;
		?invtype_shoulders -> ?equipment_slot_shoulders;
		?invtype_body -> ?equipment_slot_body;
		?invtype_chest -> ?equipment_slot_chest;
		?invtype_waist -> ?equipment_slot_waist;
		?invtype_legs -> ?equipment_slot_legs;
		?invtype_feet -> ?equipment_slot_feet;
		?invtype_wrists -> ?equipment_slot_wrists;
		?invtype_hands -> ?equipment_slot_hands;
		?invtype_finger -> ?equipment_slot_finger1;
		?invtype_trinket -> ?equipment_slot_trinket1;
		?invtype_weapon -> ?equipment_slot_mainhand;
		?invtype_shield -> ?equipment_slot_offhand;
		?invtype_ranged -> ?equipment_slot_ranged;
		?invtype_cloak -> ?equipment_slot_back;
		?invtype_2hweapon -> ?equipment_slot_mainhand;
		?invtype_tabard -> ?equipment_slot_tabard;
		?invtype_robe -> ?equipment_slot_chest;
		?invtype_weaponmainhand -> ?equipment_slot_mainhand;
		?invtype_weaponoffhand -> ?equipment_slot_offhand;
		?invtype_holdable -> ?equipment_slot_mainhand;
		?invtype_thrown -> ?equipment_slot_ranged;
		?invtype_rangedright -> ?equipment_slot_ranged;
		_ -> -1
	end.


create(ItemId, OwnerGuid) ->
	ItemGuid = world:get_guid(?highguid_item, 0),
	init_values(ItemGuid, ItemId, OwnerGuid).



init_values(ItemGuid, ItemId, OwnerGuid) ->
	ObjectType = ?typemask_item bor ?typemask_object,
	Scale = ?default_scale,

	ItemProto = content:lookup_item(ItemId),
	ItemMaxDurability = ItemProto#item_proto.max_durability,
	ItemClass = ItemProto#item_proto.class,

	StackCount = if ItemClass == ?item_class_consumable -> ?default_item_stack_size;
		true -> 1
	end,

	Charges = -1,

	KeyValues = [
		{'OBJECT_FIELD_GUID', ItemGuid, uint64},
		{'OBJECT_FIELD_TYPE', ObjectType, uint32},
    {'OBJECT_FIELD_SCALE_X', Scale, float},
    {'OBJECT_FIELD_ENTRY', ItemId, uint32},

    {'ITEM_FIELD_SPELL_CHARGES', Charges, uint32},
    {'ITEM_FIELD_SPELL_CHARGES_01', Charges, uint32},
    {'ITEM_FIELD_SPELL_CHARGES_02', Charges, uint32},
    {'ITEM_FIELD_SPELL_CHARGES_03', Charges, uint32},
    {'ITEM_FIELD_SPELL_CHARGES_04', Charges, uint32},
    {'ITEM_FIELD_OWNER', OwnerGuid, uint64},
    {'ITEM_FIELD_CONTAINED', ItemGuid, uint64},
    {'ITEM_FIELD_STACK_COUNT', StackCount, uint32},
    {'ITEM_FIELD_MAXDURABILITY', ItemMaxDurability, uint32},
    {'ITEM_FIELD_DURABILITY', ItemMaxDurability, uint32}
	],

	EmptyValues = get_empty_values(),
	lists:foldl(fun object_values:set_key_values/2, EmptyValues, KeyValues).


get_empty_values() ->
	TotalCount = update_fields:get_total_count(item),
	binary:copy(<<0?L>>, TotalCount).