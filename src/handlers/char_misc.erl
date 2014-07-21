-module(char_misc).
-export([request_raid_info/2, name_query/2, cancel_trade/2, gmticket_getticket/2]).
-export([query_next_mail_time/2, battlefield_status/2, meetingstone_info/2, zone_update/2]).
-export([tutorial_flag/2, far_sight/2]).

-include("include/binary.hrl").
-include("include/database_records.hrl").


far_sight(Data, _AccountId) ->
	Payload = recv_data:get(payload, Data),
	% dont need to do anything
	io:format("received req to set far sight: ~p~n", [Payload]),
	% do nothing and camera stays on main char
	ok.

tutorial_flag(_Data, _AccountId) ->
	io:format("received req for tutorial flag~n"),
	ok.

zone_update(_Data, _AccountId) ->
	io:format("received req for zone update~n"),
	ok.

meetingstone_info(_Data, _AccountId) ->
	io:format("received req for meetingstone info~n"),
	ok.

battlefield_status(_Data, _AccountId) ->
	io:format("received req for battlefield status~n"),
	ok.

query_next_mail_time(_Data, _AccountId) ->
	io:format("received req to query next mail time~n"),
	ok.

gmticket_getticket(Data, AccountId) ->
	% send time response first
	ok = server:query_time(Data, AccountId),

	Payload = <<16#0A?L>>,
	player_router:send(AccountId, smsg_gmticket_getticket, Payload),
	ok.

cancel_trade(_Data, _AccountId) ->
	%io:format("received req to cancel trade~n"),
	ok.

request_raid_info(_Data, AccountId) ->
	Payload = <<0?L>>,
	player_router:send(AccountId, smsg_raid_instance_info, Payload),
	ok.


name_query(Data, AccountId) ->
	Values = recv_data:get(values, Data),
	Guid = object_values:get_uint64_value('OBJECT_FIELD_GUID', Values),
	Name = char_data:get_logged_in_char_name(Guid),
	Null = <<"\0">>,
	Race = object_values:get_byte_value('UNIT_FIELD_BYTES_0', Values, 0),
	Gender = object_values:get_byte_value('UNIT_FIELD_BYTES_0', Values, 1),
	Class = object_values:get_byte_value('UNIT_FIELD_BYTES_0', Values, 2),
	Payload = <<Guid?Q, Name/binary, Null/binary, Race?L, Gender?L, Class?L>>,
	player_router:send(AccountId, smsg_name_query_response, Payload),
	ok.