-module(srp).
-export([test/0]).
-compile([export_all]).


getUsername() -> <<"alice">>.

getPassword() -> <<"password123">>.

getSalt() -> <<16#b3d47dc40109ba25459096abdd0bfbbc3266d5b2dcf52eb586d2d2e612afdd84:256>>.

getGenerator() -> <<7/integer>>.

%% srp version 6
getVersion() -> '6'.

getMultiplier() -> <<3/integer>>.

getSize() -> 256.

% randomly generated 32 byte number
generatePrivate() ->
	Size = getSize(),
	crypto:rand_bytes(Size div 8).


%% 32 byte prime number
%% used in mangos: https://github.com/mangoszero/server/blob/master/src/realmd/AuthSocket.cpp#L190
%% used in arcemu: http://arcemu.org/wiki/Server_Logon_Challenge
getPrime() ->
	Size = getSize(),
	<<16#894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7:Size>>.



%% v = g^x
getVerifier(Generator, Prime, DerivedKey) ->
	crypto:mod_pow(Generator, DerivedKey, Prime).


%% x = H(salt, H(username, :, password))
getDerivedKey(Username, Password, Salt) ->
	crypto:hash(sha, [Salt, crypto:hash(sha, [Username, <<$:>>, Password])]).

getScrambler(ClientPublic, ServerPublic) ->
	crypto:hash(sha, [ClientPublic, ServerPublic]).


%% client public key
getClientPublic(Generator, Prime, ClientPrivate) ->
	Version = getVersion(),
																																															{Pub, ClientPrivate} = crypto:generate_key(srp, {user, [Generator, Prime, Version]}, ClientPrivate),
	Pub.

%% server public key
getServerPublic(Generator, Prime, ServerPrivate, DerivedKey) ->
	Version = getVersion(),
	Verifier = getVerifier(Generator, Prime, DerivedKey),
	{Pub, ServerPrivate} = crypto:generate_key(srp, {host, [Verifier, Generator, Prime, Version]}, ServerPrivate),
Pub.


%% client session key
%% doesnt use compute_key because there currently is a bug in otp
computeClientKey(ClientPrivate, ServerPublic, ClientPublic, Generator, Prime, DerivedKey) ->
	U = getScrambler(ClientPublic, ServerPublic),
	PrimeI = bin_to_int(Prime),
	Multiplier = getMultiplier(),
	BX = crypto:mod_pow(Generator, DerivedKey, Prime),
	BTMPI0 = bin_to_int(ServerPublic) - bin_to_int(Multiplier) * bin_to_int(BX),
	BTMPI = BTMPI0 rem PrimeI,
	Base = if
			BTMPI > 0 -> int_to_bin(BTMPI);
			true -> int_to_bin(BTMPI + PrimeI)
	end,
	Exponent = int_to_bin(bin_to_int(ClientPrivate) + bin_to_int(U) * bin_to_int(DerivedKey)),
	crypto:mod_pow(Base, Exponent, Prime).


%% server session key
computeServerKey(ServerPrivate, ClientPublic, ServerPublic, Generator, Prime, DerivedKey) ->
	U = getScrambler(ClientPublic, ServerPublic),
	Version = getVersion(),
	Verifier = getVerifier(Generator, Prime, DerivedKey),
	crypto:compute_key(srp, ClientPublic, {ServerPublic, ServerPrivate}, {host, [Verifier, Prime, Version, U]}).

getM1(Prime, Generator, I, Salt, ClientPublic, ServerPublic, Key) ->
	P1 = crypto:exor(hash(Prime), hash(Generator)),
	hash([P1, hash(I), Salt, ClientPublic, ServerPublic, Key]).

getM2(ClientPublic, M1, Key) ->
	hash([ClientPublic, M1, Key]).


test() ->
	%% these session keys should match
	G = getGenerator(),
	P = getPrime(),
	U = getUsername(),
	Pw = getPassword(),
	Salt = getSalt(),
	DerivedKey = getDerivedKey(U, Pw, Salt),

	ClientPrivate = generatePrivate(),
	ServerPrivate = generatePrivate(),

	ServerPublic = getServerPublic(G, P, ServerPrivate, DerivedKey),
	ClientPublic = getClientPublic(G, P, ClientPrivate),

	ClientKey = computeClientKey(ClientPrivate, ServerPublic, ClientPublic, G, P, DerivedKey),
	ServerKey = computeServerKey(ServerPrivate, ClientPublic, ServerPublic, G, P, DerivedKey),

	io:format("client skey: ~p~n", [ClientKey]),
	io:format("server skey: ~p~n", [ServerKey]),
	ClientKey == ServerKey.


%% utility functions
hash(L) -> crypto:hash(sha, L).

int_to_bin(Int) ->
	Len0 = length(erlang:integer_to_list(Int, 16)),
	Len1 = Len0 + (Len0 rem 2),
	Bits = Len1 * 4,
	<<Int:Bits>>.

bin_to_int(Bin) ->
	Bits = byte_size(Bin) * 8,
	<<Val:Bits>> = Bin,
	Val.
