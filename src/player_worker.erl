-module(player_worker).

-export([start_link/1, call/1]).

-include("include/shared_defines.hrl").


start_link(WorkerData) ->
	Pid = spawn_link(?MODULE, call, [WorkerData]),
	{ok, Pid}.



% used to call callback functions
% if a callback returns ok, nothing happens
% if it returns {OpAtom, Payload}
% it sends that packet to this player
call({Callback, Args}) ->
	Data = recv_data:build(Args),
	M = Callback#callback.module,
	F = Callback#callback.function,

	case M:F(Data) of
		ok -> ok;
		{OpAtom, Payload} ->

			Type = case Callback#callback.send_priority of
				undefined -> enqueue;
				Prio -> Prio
			end,

			AccountId = recv_data:get(account_id, Data),
			player_controller:send(AccountId, OpAtom, Payload, Type)
	end.
