%%   This is a World of Warcraft emulator written in erlang, supporting
%%   client 1.12.x
%%
%%   Copyright (C) 2014  Jamie Clinton <jamieclinton.com>
%%
%%   This program is free software; you can redistribute it and/or modify
%%   it under the terms of the GNU General Public License as published by
%%   the Free Software Foundation; either version 2 of the License, or
%%   (at your option) any later version.
%%
%%   This program is distributed in the hope that it will be useful,
%%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%   GNU General Public License for more details.
%%
%%   You should have received a copy of the GNU General Public License along
%%   with this program; if not, write to the Free Software Foundation, Inc.,
%%   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
%%
%%   World of Warcraft, and all World of Warcraft or Warcraft art, images,
%%   and lore ande copyrighted by Blizzard Entertainment, Inc.

-module(char_data).

-export([init/0, cleanup/0]).
-export([enum_char_guids/1, delete_char/1, create_char/8]).
-export([equip_starting_items/1]).
-export([get_stored_values/1, get_char_misc/1, get_char_name/1, get_char_move/1, get_account_id/1, get_char_spells/1, get_action_buttons/1]).
-export([update_char_misc/2, update_char_move/2, update_coords/6, add_spell/2, create_action_buttons/1, update_action_button/2, update_char_values/2]).

-include("include/binary.hrl").
-include("include/database_records.hrl").
-include("include/shared_defines.hrl").
-include("include/character.hrl").

-define(char_val, characters_values).
-define(char_name, characters_names).
-define(char_misc, characters_miscellaneous).
-define(char_acc, characters_account).
-define(char_spells, characters_spells).
-define(char_btns, characters_btns).
-define(char_mv, characters_movement).


get_char_tabs() ->
	[
		?char_name,
		?char_misc,
		?char_mv,
		?char_acc,
		?char_spells,
		?char_btns,
		?char_val
	].



init() ->
	lists:foreach(fun(Tab) ->
		dets_store:open(Tab, true)
	end, get_char_tabs()),

	ok.

cleanup() ->
	lists:foreach(fun(Tab) ->
		dets_store:close(Tab, true)
	end, get_char_tabs()),
	ok.






% persistent char data

enum_char_guids(AccountId) ->
	CharsGuids = ets:match_object(?char_acc, {'_', AccountId}),
	lists:map(fun({Guid, _}) -> Guid end, CharsGuids).


get_char_misc(Guid) ->
	get_char_data(Guid, ?char_misc).

get_char_name(Guid) ->
	get_char_data(Guid, ?char_name).

get_char_move(Guid) ->
	get_char_data(Guid, ?char_mv).

get_char_spells(Guid) ->
	get_char_data(Guid, ?char_spells).

get_action_buttons(Guid) ->
	get_char_data(Guid, ?char_btns).

get_account_id(Guid) ->
	get_char_data(Guid, ?char_acc).

% should only be used when a character is not logged in
% expensive call
get_stored_values(Guid) ->
	get_char_data(Guid, ?char_val, false).

get_char_data(Guid, Tab) ->
	get_char_data(Guid, Tab, true).
get_char_data(Guid, Tab, Stored) ->
	case dets_store:lookup(Tab, Guid, Stored) of
		[] -> throw(badarg);
		[{Guid, Val}] -> Val
	end.





delete_char(Guid) ->
	lists:foreach(fun(Tab) ->
		dets_store:delete(Tab, Guid, true)
	end, get_char_tabs()),
	ok.


create_char(Guid, AccountId, CharName, CharMisc, CharMv, Values, Spells, ActionButtons) when is_integer(Guid), is_binary(Values), is_binary(CharName), is_record(CharMisc, char_misc), is_record(CharMv, char_move), is_binary(AccountId), is_record(Spells, char_spells), is_binary(ActionButtons) ->
	DetsValues = [
		{?char_name, CharName},
		{?char_misc, CharMisc},
		{?char_mv, CharMv},
		{?char_acc, AccountId},
		{?char_btns, ActionButtons},
		{?char_spells, Spells},
		{?char_val, Values}
	],
	lists:foreach(fun({Tab, Val}) ->
		dets_store:store_new(Tab, {Guid, Val}, true),
		ok
	end, DetsValues),

	ok.


update_char_values(Guid, Values) when is_binary(Values) ->
	dets_store:store(?char_val, {Guid, Values}, true).

update_char_misc(Guid, CharMisc) when is_record(CharMisc, char_misc) ->
	dets_store:store(?char_misc, {Guid, CharMisc}, true).


update_char_move(Guid, CharMove) ->
	dets_store:store(?char_mv, {Guid, CharMove}, true).

update_coords(Guid, X, Y, Z, O, MovementInfo) ->
	CharMv = get_char_move(Guid),
	NewCharMv = CharMv#char_move{x=X, y=Y, z=Z, orient=O, movement_info=MovementInfo},
	dets_store:store(?char_mv, {Guid, NewCharMv}, true).


equip_starting_items(Guid) ->
	Values = get_stored_values(Guid),

	Race = char_values:get_value({unit_field_bytes_0, 0}, Values),
	Class = char_values:get_value({unit_field_bytes_0, 1}, Values),
	Gender = char_values:get_value({unit_field_bytes_0, 2}, Values),

	StartingItemIds = static_store:lookup_start_outfit(Race, Class, Gender, true),
	NewValues = lists:foldl(fun(ItemId, ValuesAcc) ->
		item:equip_new(ItemId, ValuesAcc, Guid)
	end, Values, StartingItemIds),
	update_char_values(Guid, NewValues),
	ok.


create_action_buttons(ActionButtonData) ->
	Data = init_action_buttons(),
	lists:foldl(fun(ActionButtonDatum, ActionButtons) ->
		insert_action_button(ActionButtonDatum, ActionButtons)
	end, Data, ActionButtonData).


update_action_button(Guid, ActionButtonDatum) ->
	ActionButtons = get_action_buttons(Guid),
	NewActionButtons = insert_action_button(ActionButtonDatum, ActionButtons),
	dets_store:store(?char_btns, {Guid, NewActionButtons}, true).

insert_action_button({Button, Action, Type}, ActionButtons) ->
	% each button is store as 4 bytes
	Offset = Button * 4,
	<<Head:Offset/binary, _?L, Rest/binary>> = ActionButtons,
	NewActionButton = Action bor (Type bsl 24),
	<<Head/binary, NewActionButton?L, Rest/binary>>.

init_action_buttons() ->
	binary:copy(<<0?L>>, ?max_action_buttons).



add_spell(Guid, SpellId) ->
	Record = get_char_spells(Guid),
	Ids = Record#char_spells.ids,
	InList = lists:any(fun(Id) -> SpellId == Id end, Ids),
	if not InList ->
			NewList = [SpellId|Ids],
			NewRecord = Record#char_spells{ids=NewList},
			dets_store:store(?char_spells, {Guid, NewRecord}, true);
		InList -> ok
	end.
