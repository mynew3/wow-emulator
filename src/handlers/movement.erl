-module(movement).
-export([handle_movement/1]).
-export([set_active_mover/1, stand_state_change/1, move_time_skipped/1]).

-include("include/binary.hrl").
-include("include/database_records.hrl").


-define(MAX_NUMBER_OF_GRIDS, 64).
-define(SIZE_OF_GRIDS, 533.33333).
-define(MAP_SIZE, ?SIZE_OF_GRIDS*?MAX_NUMBER_OF_GRIDS).
-define(MAP_HALFSIZE, ?MAP_SIZE/2).



move_time_skipped(_Data) ->
	% this is used if you need to modify last move time
	% but not needed for now

	%<<Guid?Q, Time?L>> = recv_data:get(payload, Data),
	%then subtract Time from last move time maybe?
	
	ok.

stand_state_change(Data) ->
	<<AnimState?B>> = recv_data:get(payload, Data),
	Guid = recv_data:get(guid, Data),
	{Guid, CharName, AccountId, Char, Values} = char_data:get_char_data(Guid),
	NewValues = object_values:set_byte_value('UNIT_FIELD_BYTES_1', AnimState, Values, 0),
	CharData = {Guid, CharName, AccountId, Char, NewValues},
	char_data:update_char(CharData),
	{smsg_standstate_update, AnimState}.


set_active_mover(_Data) ->
	% dont need to do anything
	ok.

handle_movement(Data) ->
	Payload = recv_data:get(payload, Data),
	MoveData = move_info:read(Payload),

	{X, Y, Z, O} = move_info:get_coords(MoveData),
	Allowable = verify_movement(X, Y, Z, O),

	if Allowable ->
			OpAtom = recv_data:get(op_atom, Data),
			Guid = recv_data:get(guid, Data),
			{Guid, CharName, AccountId, Char, Values} = char_data:get_char_data(Guid),
			NewChar = Char#char{position_x = X, position_y = Y, position_z = Z, orientation = O},
			CharData = {Guid, CharName, AccountId, NewChar, Values},
			char_data:update_char(CharData),

			PackGuid = <<7?B, Guid?G>>,
			Time = move_info:get_value(time, MoveData),
			NewTime = Time + 500,
			MoveData2 = move_info:update(time, NewTime, MoveData),
			NewPayload = move_info:write(MoveData2),
			Msg = <<PackGuid/binary, NewPayload/binary>>,
			world:send_to_all_but_player(OpAtom, Msg, Guid);
		not Allowable ->
			io:format("bad movement data passed in: ~p~n", [Payload]),
			ok
	end,
	ok.




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
