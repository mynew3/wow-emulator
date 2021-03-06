-type key_state() :: {non_neg_integer(), non_neg_integer(), [integer()]}.
-type maybe_key_state() :: 'nil' | key_state().

-type guid() :: 1..16#FFFFFFFF.
-type maybe_zero_guid() :: 0 | guid().

-type value_type() :: uint64 | uint32 | int32 | uint16 | uint8 | float.

-type player_values() :: <<_:5128>>. % byte size of player values
-type item_values() :: <<_:192>>. % byte size of item values
-type any_values() :: player_values() | item_values().

-type gender() :: male | female | none.
-type race() :: human | orc | dwarf | night_elf | undead | tauren | gnome | troll.
-type class() :: warrior | paladin | hunter | rogue | priest | shaman | mage | warlock | druid.


-type field_data() :: {atom(), non_neg_integer()} | atom().

-type recv_data() :: [{atom(), term()}].
-type handler_response() :: 'ok' | {atom(), binary()}.
