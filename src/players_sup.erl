-module(players_sup).
-behavior(supervisor).

-export([start_link/0, start_socket/0, get_count/0]).
-export([init/1]).


get_count() ->
	supervisor:count_children(?MODULE).

start_link() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
	{ok, Port} = application:get_env(world_port),
	{ok, ListenSocket} = gen_tcp:listen(Port, [{active,false}, binary, {reuseaddr, true}]),
	spawn_link(fun() ->
		empty_listeners()
	end),
	{ok, {{simple_one_for_one, 60, 3600},
				[{player_sup,
					{player_sup, start_link, [ListenSocket]},
					temporary, 10000, supervisor, [player_sup]}
				]}}.

start_socket() ->
	supervisor:start_child(?MODULE, []).

empty_listeners() ->
	[start_socket() || _ <- lists:seq(1,1)],
	ok.