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

-module(client_controller).
-behavior(gen_server).

-record(state, {
	account_id,
  send_pid
 }).


-export([start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).
-export([tcp_packet_received/3]).
-export([move/0, move/1]).
-export([logout/0, logout/1]).
-export([sit/0, sit/1]).
-export([stand/0, stand/1]).
-export([cast/0]).
-export([get_dummy_account/0]).


-include("include/binary.hrl").
-include("include/database_records.hrl").


get_dummy_account() ->
	<<"ALICE2">>.

stand() ->
	AccountId = get_dummy_account(),
	stand(AccountId).
stand(AccountId) ->
	Pid = get_pid(AccountId),
	gen_server:cast(Pid, stand).
sit() ->
	AccountId = get_dummy_account(),
	sit(AccountId).
sit(AccountId) ->
	Pid = get_pid(AccountId),
	gen_server:cast(Pid, sit).
move() ->
	AccountId = get_dummy_account(),
	move(AccountId).
move(AccountId) ->
	Pid = get_pid(AccountId),
	gen_server:cast(Pid, move).

logout() ->
	AccountId = get_dummy_account(),
	logout(AccountId).
logout(AccountId) ->
	Pid = get_pid(AccountId),
	gen_server:cast(Pid, logout).

cast() ->
	AccountId = get_dummy_account(),
	Pid = get_pid(AccountId),
	gen_server:cast(Pid, cast).


tcp_packet_received(AccountId, Opcode, Payload) ->
	Msg = {tcp_packet_rcvd, {Opcode, Payload}},
	%% sends to a process that handles the operation for this opcode, probaly a 'user' process
	Pid = get_pid(AccountId),
	gen_server:cast(Pid, Msg).

get_pid(Name) ->
	util:get_pid(?MODULE, Name).




	

start_link(AccountId, SendPid) ->
	gen_server:start_link(?MODULE, {AccountId, SendPid}, []).

init({AccountId, SendPid}) ->
	io:format("controller SERVER: started for ~p~n", [AccountId]),
	process_flag(trap_exit, true),

	util:reg_proc(?MODULE, AccountId),

	{ok, #state{send_pid=SendPid, account_id=AccountId}}.


handle_cast(stop, State) ->
	{stop, done, State};
handle_cast(cast, State) ->
	OpAtom = cmsg_cast_spell,
	Payload = <<687?L, 0?W>>,
	gen_server:cast(self(), {send_to_server, {OpAtom, Payload}}),
	{noreply, State};
handle_cast(stand, State) ->
	OpAtom = cmsg_standstatechange,
	AnimState = 0,
	Payload = <<AnimState?L>>,
	gen_server:cast(self(), {send_to_server, {OpAtom, Payload}}),
	{noreply, State};
handle_cast(sit, State) ->
	OpAtom = cmsg_standstatechange,
	AnimState = 1,
	Payload = <<AnimState?L>>,
	gen_server:cast(self(), {send_to_server, {OpAtom, Payload}}),
	{noreply, State};
handle_cast(logout, State) ->
	OpAtom = cmsg_logout_request,
	Payload = <<>>,
	gen_server:cast(self(), {send_to_server, {OpAtom, Payload}}),
	{noreply, State};
handle_cast(move, State) ->
	OpAtom = msg_move_start_forward,
	Char = #char_move{ x = -8949.95, y = -132.493, z = 83.5312, orient = 0},
	X = Char#char_move.x,
	Y = Char#char_move.y,
	Z = Char#char_move.z,
	O = Char#char_move.orient,
	Time = util:game_time(),
	Fall = 0,
	MoveFlags = 1,
	Payload = <<MoveFlags?L, Time?L, X?f, Y?f, Z?f, O?f, Fall?f>>,
	gen_server:cast(self(), {send_to_server, {OpAtom, Payload}}),
	{noreply, State};
handle_cast({tcp_packet_rcvd, {Opcode, Payload}}, State) ->
	handle_response(Opcode, Payload),
	{noreply, State};
handle_cast({send_to_server, {OpAtom, Payload}}, S=#state{send_pid = SendPid}) ->
	Opcode = opcodes:get_num_by_atom(OpAtom),
	client_send:send_msg(SendPid, Opcode, Payload),
	{noreply, S};
handle_cast(Msg, S) ->
	io:format("unknown casted message: ~p~n", [Msg]),
	{noreply, S}.


handle_call(_E, _From, State) ->
	{reply, ok, State}.

handle_info(upgrade, State) ->
	%% loads latest code
	?MODULE:handle_info(do_upgrade, State),
	{noreply, State};
handle_info(Msg, State) ->
	io:format("unknown message: ~p~n", [Msg]),
	{noreply, State}.


code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

terminate(_Reason, _State) ->
	io:format("WORLD: shutting down controller~n"),
	ok.


%private

handle_response(Opcode, Payload) ->
	OpAtom = opcodes:get_atom_by_num(Opcode),
	%io:format("client looking up opcode: ~p~n", [OpAtom]),
	Fun = lookup_opcode(OpAtom),
	if Fun /= none ->
			case Fun(Payload) of
				ok -> ok;
				Msg ->
					gen_server:cast(self(), {send_to_server, Msg}),
					ok
			end;
		Fun == none ->
			ok
	end.

lookup_opcode(smsg_char_enum) -> fun player_login/1;
lookup_opcode(smsg_auth_response) -> fun send_char_enum/1;
lookup_opcode(smsg_logout_complete) -> fun player_logout/1;
lookup_opcode(_) -> none.


player_logout(_) ->
	gen_server:cast(self(), stop),
	ok.


player_login(Payload) ->
	EQUIPMENT_SLOT_END = 19,
	SlotDataSize = EQUIPMENT_SLOT_END * 40,
	<<Num?B, CharData/binary>> = Payload,
	<<Guid?Q,
	NameNum1?B,
	NameNum2?B,
	NameNum3?B,
	NameNum4?B,
	0?B,
	_Race?B,
	_Class?B,
	_Gender?B,
	_Skin?B,
	_Face?B,
	_HairStyle?B,
	_HairColor?B,
	_FacialHair?B,
	_Level?B,
	_Zone?L,
	_Map?L,
	_X?f,
	_Y?f,
	_Z?f,
	_GuildId?L,
	_GeneralFlags?L,
	_AtLoginFlags?B,
	_PetDisplayId?L,
	_PetLevel?L,
	_PetFamily?L,
	_SlotData:SlotDataSize/unsigned-little-integer,
	_BagDisplayId?L,
	_BagInventoryType?B>> = CharData,
	Name = [NameNum1, NameNum2, NameNum3, NameNum4],
	io:format("received enum with ~p chars. name: ~p guid: ~p~n", [Num, Name, Guid]),
	% send login
	{cmsg_player_login, <<Guid?Q>>}.


send_char_enum(_) ->
	{cmsg_char_enum, <<0?L>>}.
		
