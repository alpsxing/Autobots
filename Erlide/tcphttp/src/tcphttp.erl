%% Author: cn569363
%% Created: 2012-9-25
%% Description: TODO: Add description to tcphttp

%%====================================================================  
%% Note : io:format should be removed in the final version
%%====================================================================  

-module(tcphttp).

%%
%% Include files
%%

-import(dataprocessor).

%%
%% Exported Functions
%%

-export([start/0,start/1,startx/0,stop/0]).

%%
%% Data Structure 
%%

%%
%% state : conn_created
%%         conn_create_fail
%%         conn_create_error
%%         ? 
%%         ?
%%

%%-record(socketinfo,{address,port,state,bin}).

%%
%% API Functions
%%

startx() ->
	start("http://api.21com.com/").

start() ->
	start("http://localhost:8080/").

start(HttpServer) ->
	init([]),
	processsavedrequests(),
	%% {active,once} can make the server safe in case of huge amount of requests.
	try gen_tcp:listen(5080,[binary,{packet,0},{reuseaddr,true}, {active,once}]) of
	    {ok,Listen} ->
			io:format("Server start~n"),
			spawn(fun() -> connect(Listen,HttpServer) end);
	    {error,Reason} ->
			dataprocessor:logmessage("Server fail to start : ~p~n", [Reason]),
			io:format("Server fail to start : ~p~n", [Reason]),
			io:format("Exit"),
			exit(start)
	catch
		_:Why ->
			io:format("Server cannot start : ~p~n", [Why]),
			io:format("Exit"),
			exit(start)
	end.

stop() ->
	ets:delete(tcpclienttable),
	ok.

%%
%% Local Functions
%%

%%
%% What is the purpose of the table?
%% Is it necessary that we keep each request from the tcp client or response from the http server?
%%
init([]) ->
	{ok, ets:new(tcpclienttable,[])}.

connect(Listen,HttpServer) ->
	%% Do we need timeout for accept here?
    try	gen_tcp:accept(Listen) of
		{ok,Socket} ->
			%% debug
			%% check client ip and address
           	%%{ok,{Address,Port}} = inet:peername(Socket),
			%%io:format("Current socket : ~p:~p~n", [Address, Port]),
			%% end debug
           	spawn(fun() -> connect(Listen,HttpServer) end),
           	loop(Socket,HttpServer);
		{error,Reason} ->
			dataprocessor:logmessage("Socket creation fails : ~p~n", [Reason]),
			io:format("Socket creation fails : ~p~n", [Reason]),
			%% Do we need to start new process again?
           	%% Is there any potential issue?
           	spawn(fun() -> connect(Listen,HttpServer) end)
	catch
		_:Why ->
			dataprocessor:logmessage("Socket creation error : ~p~n", [Why]),
			io:format("Socket creation error : ~p~n", [Why]),
			%% Do we need to start new process again?
           	%% Is there any potential issue?
           	%%spawn(fun() -> connect(Listen,HttpServer) end),
			exit(Why)
	end.

loop(Socket,HttpServer) ->
	receive
		{tcp,Socket,Bin} ->
			%% further usage
			%%TimeStamp = calendar:now_to_local_time(erlang:now()),
			%%dataprocessor:savesocketbin(true,Socket,Bin,TimeStamp),
			%%io:format("Server received binary = ~p~n",[Bin]),
			%% will crash, why?
			%%Str = binary_to_term(Bin),
			%%io:format("Server (unpacked) ~p~n",[Str]),
            HttpBin = dataprocessor:tcp2http(Bin),
            %%io:format("Server processed received binary = ~p~n",[HttpBin]),
			%% will crash, why?
			%%HttpStr = binary_to_term(HttpBin),
			%%io:format("Server processed (unpacked) ~p~n",[HttpStr]),
			case connecthttpserver(HttpBin,HttpServer) of
				{ok,HttpBinResp} ->
					%% further usage
					%%dataprocessor:deletesocketbin(true,Socket,TimeStamp),
    			    %% debug
                    %%io:format("Http Client received binary = ~p~n",[HttpBinResp]),
					%% end debug
                    %% will crash, why?
					%%HttpStrResp = binary_to_term(HttpBinResp),
    			    %% debug
                    %%io:format("Http Client processed (unpacked) ~p~n",[HttpStrResp]),
			        %% end debug
					%% further usage
                    %%dataprocessor:savesocketbin(false,Socket,HttpBinResp,TimeStamp),
					try gen_tcp:send(Socket,HttpBinResp) of
						ok ->
							%% further usage
		                    %%dataprocessor:deletesocketbin(false,Socket,HttpBinResp,TimeStamp),
							ok;
						{error,Reason} ->
           					{ok,{Address,Port}} = inet:peername(Socket),
							dataprocessor:logmessage("Tcp server response fails : ~p:~p : ~p~n",[Address,Port,Reason]),
				            io:format("Tcp server response fails : ~p:~p : ~p~n",[Address,Port,Reason]),
                            ok
					catch
						_:Why ->
							dataprocessor:logmessage("Tcp server reponse error : ~p~n", [Why]),
							io:format("Tcp server reponse error : ~p~n", [Why]),
							ok
					end;
				{error} ->
					{ok,{Address,Port}} = inet:peername(Socket),
					dataprocessor:logmessage("Server connect http server error : ~p:~p~n",[Address,Port]),
		            io:format("Server connect http server error : ~p:~p~n",[Address,Port]),
                    ok
			end,
 	        inet:setopts(Socket,[{active,once}]),
            loop(Socket,HttpServer);
		_ ->
            ok
    end.
	
connecthttpserver(Bin,HttpServer) ->
	%% debug
	%%io:format("Http Server : ~p~n",[HttpServer]),
	%% end debug
	inets:start(),
	%% debug
    %%io:format("Try httpc:request(...)...~n"),
	%% end debug
	try httpc:request(post, {HttpServer, [], "", Bin}, [], []) of
		{ok,{StatusLine, Headers, Body}} ->
			%%inets:stop(),
			%% debug
			StatusLine,
			Headers,
			%%io:format("StatusLine : ~p~n",[StatusLine]),
			%%io:format("Headers : ~p~n",[Headers]),
			%% end debug
			{ok,Body};
		{ok,{StatusCode, Body}} ->
			%%inets:stop(),
			%% debug
			io:format("StatusCode : ~p~n",[StatusCode]),
			%% end debug
			{ok,Body};
		{ok,RequestID} ->
			%%inets:stop(),
			%% debug
			io:format("RequestID : ~p~n",[RequestID]),
			%% end debug
			{error};
		%%{ok,saved_to_file} ->
		%%	%% debug
		%%	io:format("ok,saved_to_file : ~p~n",[saved_to_file]),
		%%	%% end debug
		%%	{error};
		{error,Reason} ->
			%%inets:stop(),
			%% debug
			io:format("error,Reason : ~p~n",[Reason]),
			%% end debug
			{error}
	catch
		_:Why ->
			inets:stop(),
			%% debug
			io:format("_:Why : ~p~n",[Why]),
			%% end debug
			{error}
	end.
	%%inets:stop().

%% Each time when the server startup,
%% the saved old requests should first be processed.
processsavedrequests() ->
	ok.

