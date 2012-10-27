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

%%
%% Local Functions
%%
