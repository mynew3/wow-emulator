-module(movement).
-export([handle_movement/2, set_active_mover/2, stand_state_change/2, move_time_skipped/2]).
-export([move_fall_land/2]).
-export([null/0]).

-include("include/binary.hrl").


-define(MAX_NUMBER_OF_GRIDS, 64).
-define(SIZE_OF_GRIDS, 533.33333).
-define(MAP_SIZE, ?SIZE_OF_GRIDS*?MAX_NUMBER_OF_GRIDS).
-define(MAP_HALFSIZE, ?MAP_SIZE/2).


move_fall_land(_Data, _AccountId) ->
	io:format("received req to move time land~n"),
	ok.


move_time_skipped(_Data, _AccountId) ->
	io:format("received req to move time skipped~n"),
	ok.

stand_state_change(_Data, _AccountId) ->
	io:format("received req to set stand state change~n"),
	ok.

set_active_mover(_Data, _AccountId) ->
	% dont need to do anything
	%io:format("received req to set active mover~n"),
	ok.

handle_movement(Data, AccountId) ->
	Values = recv_data:get(values, Data),
	Guid = object_values:get_uint64_value('OBJECT_FIELD_GUID', Values),
	PackGuid = <<7?B, Guid?G>>,

	Payload = recv_data:get(payload, Data),
	<<MoveFlags?L, Time?L, X?f, Y?f, Z?f, O?f, _Unk1?L>> = Payload,
	NewPayload = <<MoveFlags?L, Time?L, X?f, Y?f, Z?f, O?f>>,
	Allowable = verify_movement(X, Y, Z, O),
	Msg = <<PackGuid/binary, NewPayload/binary>>,
	%io:format("moveflags: ~p pos: {~p,~p,~p,~p} time: ~p unk1: ~p~n", [MoveFlags, X, Y, Z, O, Time, Unk1]),
	if Allowable ->
			world:send_to_all_but_player(msg_move_start_forward, Msg, AccountId);
		not Allowable ->
			io:format("bad movement data passed in: ~p~n", [Payload]),
			ok
	end,
	ok.

null() -> ok.




%%%%%%%%%%%%%%%%%%%%%
%% private

verify_movement(X, Y, Z, O) ->
	finite(O) andalso verify_movement(X, Y, Z).

verify_movement(X, Y, Z) ->
	finite(Z) andalso verify_movement(X, Y).

verify_movement(X, Y) ->
	verify_movement(X) andalso verify_movement(Y).

verify_movement(C) ->
	finite(C) andalso (abs(C) =< ?MAP_HALFSIZE - 0.5).
	



% just check if its a 32 bit number
%finite(C) -> C band 16#00000000 == 0.
finite(_) -> true.
