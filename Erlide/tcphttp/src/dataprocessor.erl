%% Author: cn569363
%% Created: 2012-9-25
%% Description: TODO: Add description to dataprocessor

-module(dataprocessor).

%%
%% Include files
%%

%%
%% Exported Functions
%%

-export([http2tcp/1, tcp2http/1]).
-export([savesocketbin/4, deletesocketbin/3]).
-export([logmessage/2, logmessage/3,logmessagetryagain/3,logmessagetryagain/4]).

%%
%% API Functions
%%

%%
%% Convert the data from terminal to http package
%%
tcp2http(Bin) ->
    Bin.

%%
%% Convert the data from http to terminal package
%%
http2tcp(Bin) ->
    Bin.

%%
%% State : true -> request from tcp client
%%       : false -> response from http server
%%
savesocketbin(State,Socket,Bin,TimeStamp) ->
	%% debug
    io:format("Enter savesocketbin~n"),
	{ok,{Address,Port}} = inet:peername(Socket),
    io:format("Address:Port - ~p:~p~n",[Address,Port]),
    io:format("State - ~p~n",[State]),
    io:format("Bin - ~p~n",[Bin]),
    io:format("TimeStamp - ~p~n",[TimeStamp]),
    io:format("Exit savesocketbin~n"),
	%% end debug
	%%{ok,{Address,Port}} = inet:peername(Socket),
	%%State,
	%%Address,
	%%Port,
    %%Bin,
	%%TimeStamp,
	ok.

deletesocketbin(State,Socket,TimeStamp) ->
	%% debug
    io:format("Enter deletesocketbin~n"),
	{ok,{Address,Port}} = inet:peername(Socket),
    io:format("Address:Port - ~p:~p~n",[Address,Port]),
    io:format("State - ~p~n",[State]),
    io:format("TimeStamp - ~p~n",[TimeStamp]),
    io:format("Exit deletesocketbin~n"),
	%% end debug
	%%{ok,{Address,Port}} = inet:peername(Socket),
	%%State,
	%%Address,
	%%Port,
	%%TimeStamp,
	ok.

logmessage(Format,StateTable) ->
	%% !!!
	%% Some log here
	%% !!!
	[{displaylog,Value}] = ets:lookup(StateTable, displaylog),
	if
		Value == true ->
			io:format(Format);
		Value == false ->
			ok
	end.

logmessagetryagain(Format,Count,StateTable) ->
	%% !!!
	%% Some log here
	%% !!!
	[{displaylog,Value}] = ets:lookup(StateTable, displaylog),
	if
		Value == true ->
			io:format(Format),
			io:format("Total fails and exceptions count : ~p~n",[Count]),
			io:format("Try again~n");
		Value == false ->
			ok
	end.

logmessagetryagain(Format,Data,Count,StateTable) ->
	%% !!!
	%% Some log here
	%% !!!
	[{displaylog,Value}] = ets:lookup(StateTable, displaylog),
	if
		Value == true ->
			io:format(Format,Data),
			io:format("Total fails and exceptions count : ~p~n",[Count]),
			io:format("Try again~n");
		Value == false ->
			ok
	end.

logmessage(Format,Data,StateTable) ->
	%% !!!
	%% Some log here
	%% !!!
	[{displaylog,Value}] = ets:lookup(StateTable, displaylog),
	if
		Value == true ->
			io:format(Format,Data);
		Value == false ->
			ok
	end.

%%
%% Local Functions
%%
