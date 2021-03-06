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

-module(guid).

-export([format/3]).
-export([pack/1, unpack/1]).
-export([int_to_bin/1, bin_to_int/1]).
-export([extract_packed/1]).

-include("include/binary.hrl").


		% first byte is a mask that tells you the size of the guid
		% eg for a 3 byte guid,
		% 7 = (1 << 0) bor (1 << 1) bor (1 << 2)
		% objects can be a maximum up to 8 bytes
pack(Guid) when is_integer(Guid), Guid >= 0 ->
	%<<7?B, Guid?G>>.
	% set GuidBin to big endian to make it easier to recurse
	GuidBin = <<Guid?QB>>,
	{Count, Mask} = pack(GuidBin, 8, 16#FF),
	Size = Count * 8,
	<<Mask?B, Guid:Size/unsigned-little-integer>>.
pack(<<0?B, Rest/binary>>, Count, Mask) ->
	pack(Rest, Count-1, Mask bsr 1);
pack(_, Count, Mask) -> {Count, Mask}.


unpack(<<Mask?B, PackGuid/binary>>) ->
	unpack(Mask, PackGuid).
unpack(16#FF, PackGuid) -> PackGuid;
unpack(Mask, PackGuid) ->
	NewMask = (Mask bsl 1) bor 1,
	unpack(NewMask, <<PackGuid/binary, 0?B>>).

int_to_bin(Guid) when is_integer(Guid) ->
	<<Guid?Q>>.

bin_to_int(GuidBin) when is_binary(GuidBin) ->
	Size = byte_size(GuidBin) * 8,
	<<Guid:Size/unsigned-little-integer>> = GuidBin,
	Guid.


format(HighGuid, Entry, LowGuid) ->
	LowGuid bor (Entry bsl 24) bor (HighGuid bsl 48).



% takes a binary with a leading packed guid
% extracts the guid and returns the guid and the rest of the bin
extract_packed(<<Mask?B, Rest/binary>>) ->
	extract_packed(Mask, Rest, <<>>).
extract_packed(0, Rest, Guid) -> {Guid, Rest};
extract_packed(Mask, <<Digit?B, Rest/binary>>, Acc) ->
	extract_packed(Mask bsr 1, Rest, <<Acc/binary, Digit?B>>).
