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
%% Definitions
%%

-define(ACCEPT_ERROR_MAX_COUNT,(9)).
%% Send the message from the terminal to the http server
-define(CONNECT_HTTP_MAX_COUNT,(3)).
%% Send the message from the terminal to the two jit servers
-define(CONNECT_JIT_MAX_COUNT,(3)).
%% Send the message from the jit server to the terminal
-define(REPONSE_TERMINAL_MAX_COUNT,(3)).

-define(TERMINAL_TCP_RECEIVE_TIMEOUT,(60000)).
-define(JIT_TCP_RECEIVE_TIMEOUT,(10000)).

-define(HTTP_SERVER,("http://127.0.0.1:8080/")).
-define(HTTP_SERVER_HOSTNAME,("http://localhost:8080/")).
-define(HTTP_SERVER_NOPORT,("http://127.0.0.1/")).
-define(HTTP_SERVER_HOSTNAME_NOPORT,("http://localhost/")).

-define(TERMINAL_LISTEN_PORT,(5080)).
-define(MASTER_TCP_SERVER,("127.0.0.1")).
-define(MASTER_TCP_SERVER_PORT,(5082)).
-define(SLAVE_TCP_SERVER,("127.0.0.1")).
-define(SLAVE_TCP_SERVER_PORT,(5082)).

-define(MANAGEMENT_LISTEN_PORT,(5081)).

-define(TO_HTTP_MAX_MESSAGE_COUNT,(100)).
-define(TO_JIT_MAX_MESSAGE_COUNT,(100)).


%%
%% Exported Functions
%%

%%
%% For test purpose
%%
-export([start0/0,start0/1,start1/0,start1/1,start2/0,start2/1]).
%%
%% Release version
%%
-export([start/0,start/1,start/6,stop/0]).

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

%%
%% For test purpose
%%
start0() ->
	start("http://127.0.0.1:8080/",?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,false).

%%
%% For test purpose
%%
start0(DisplayLog) ->
	start("http://127.0.0.1:8080/",?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,DisplayLog).

%%
%% For test purpose
%%
start1() ->
	start("http://google.com/",?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,false).

%%
%% For test purpose
%%
start1(DisplayLog) ->
	start("http://google.com/",?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,DisplayLog).

%%
%% For test purpose
%%
start2() ->
	start("http://api.21com.com/",?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,false).

%%
%% For test purpose
%%
start2(DisplayLog) ->
	start("http://api.21com.com/",?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,DisplayLog).

start() ->
	start(?HTTP_SERVER,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,false).

start(DisplayLog) ->
	start(?HTTP_SERVER,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,DisplayLog).

start(HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,DisplayLog) ->
	init(DisplayLog),
	%% !!!
	%% In the previous definition, the messsages from the terminal, the http server and the jit servers should be kept in the file.
	%% Only after the messages have been processed correctly, can they be removed.
    %% Whether is it a correct design or is there any other better solution?
	%% !!!
	processsavedrequests(),
	%% {active,once} can make the server safe in case of huge amount of requests.
	%% !!!
	%% Please check the parameters of this method gen_tcp:listen(...)
	%% !!!
	try gen_tcp:listen(?TERMINAL_LISTEN_PORT,[binary,{packet,0},{reuseaddr,true}, {active,once}]) of
	    {ok,Listen} ->
			logmessage("Server start~n"),
			spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,1) end);
	    {error,Reason} ->
			stop(),
			logmessage("Server start fails : ~p~n", [Reason]),
			logmessage("Ignore failure and exit~n"),
			exit(Reason)
	catch
		_:Why ->
			stop(),
			logmessage("Server start exception : ~p~n", [Why]),
			logmessage("Ignore exception and exit~n"),
			exit(Why)
	end,
	try gen_tcp:listen(?MANAGEMENT_LISTEN_PORT,[binary,{packet,0},{reuseaddr,true}, {active,once}]) of
	    {ok,ListenMan} ->
			logmessage("Server management start~n"),
			spawn(fun() -> connectmanagement(ListenMan,1) end);
	    {error,ReasonMan} ->
			stop(),
			logmessage("Server management start fails : ~p~n", [ReasonMan]),
			logmessage("Ignore failure and exit~n"),
			exit(ReasonMan)
	catch
		_:WhyMan ->
			stop(),
			logmessage("Server management start exception : ~p~n", [WhyMan]),
			logmessage("Ignore exception and exit~n"),
			exit(WhyMan)
	end,
	try inets:start() of
		ok ->
			logmessage("Server http client start~n");
		{error,ReasonInets} ->
			logmessage("Server http client fails : ~p~n",[ReasonInets]),
			logmessage("Ignore failure and exit~n"),
			exit(ReasonInets)
	catch
		_:WhyInets ->
			logmessage("Server http client exception : ~p~n",[WhyInets]),
			logmessage("Ignore failure and exit~n"),
			exit(WhyInets)
	end.

%%
%% There should be a better mechanism to stop the server.
%% One idea is each process will be registered and set a flag.
%% So when we want to stop, we will cancel all process be the registries and the flag.
%% Not implemented yet.
%%
stop() ->
	ets:delete(serverstatetable),
	ets:delete(msg2jittable),
	ets:delete(msg2httptable),
	ok.

%%
%% Local Functions
%%

%%
%% What is the purpose of the table?
%% Is it necessary that we keep each request from the tcp client or response from the http server?
%%
%%
init(DisplayLog) ->
	ets:new(serverstatetable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	%% When released, displaylog should be false.
	ets:insert(serverstatetable,{displaylog,DisplayLog}),
	ets:insert(serverstatetable,{usemastertcpserver,true}),
	ets:insert(serverstatetable,{jitserverfailures,0}),
	ets:insert(serverstatetable,{httpserverfailures,0}),
	ets:insert(serverstatetable,{acceptfailures,0}),
	ets:insert(serverstatetable,{acceptmanagementfailures,0}),
	ets:insert(serverstatetable,{accepthttpfailures,0}),
	ets:new(msg2terminaltable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(msg2jittable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(msg2httptable,[duplicate_bag,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]).

%%
%% Management, for example, stop server, enaable/disable display, switch jit master/slave and etc.
%%
connectmanagement(Listen,Count) ->
	if
		Count > ?ACCEPT_ERROR_MAX_COUNT ->
			stop(),
			logmessage("Accept management terminal fails continously ~p times and stop accepting~n",[?ACCEPT_ERROR_MAX_COUNT]),
			exit("Stop accepting management terminal because of too many failures/exceptions~n");
		Count =< ?ACCEPT_ERROR_MAX_COUNT ->
			%% !!!
			%% Do we need timeout for accept here?
			%% It seems to be unnecessary.
			%% !!!
		    try	gen_tcp:accept(Listen) of
				{ok,Socket} ->
		           	spawn(fun() -> connectmanagement(Listen,1) end),
					logmessage("Accept current management socket : ~p~n", [Socket]),
		           	loopmanagement(Socket);
				{error,Reason} ->
					[{acceptmanagementfailures,ErrorCount}] = ets:lookup(serverstatetable, acceptmanagementfailures),
					ets:insert(serverstatetable, {acceptmanagementfailures,ErrorCount+1}),
					logmessage("Accepting management total failures/exceptions : ~p~n", [ErrorCount+1]),
					logmessagetryagain("Accepting management failure : ~p~n",[Reason],Count),
		           	spawn(fun() -> connectmanagement(Listen,Count+1) end)
			catch
				_:Why ->
					[{acceptmanagementfailures,ExceptionCount}] = ets:lookup(serverstatetable, acceptmanagementfailures),
					ets:insert(serverstatetable, {acceptmanagementfailures,ExceptionCount+1}),
					logmessage("Accepting management total failures/exceptions : ~p~n", [ExceptionCount+1]),
					logmessagetryagain("Accepting management exception : ~p~n",[Why],Count),
		           	spawn(fun() -> connectmanagement(Listen,Count+1) end)
			end
	end.

loopmanagement(Socket) ->
	receive
		{tcp,Socket,Bin} ->
			%% !!!
			%% Do management here, for example, stop server, enaable/disable display, switch jit master/slave and etc.
			%% !!!
			BinResp = processmanagementdata(Bin),
			connecttcpterminal(Socket,BinResp,1,true);
		{tcp_closed,Socket} ->
			logmessage("Management terminal close socket - ~p~n", [Socket]);
		{tcp_error,Socket} ->
			logmessage("Management terminal socket - ~p - error :  ~p~n", [Socket,tcp_error]),
			logmessage("Close management terminal socket~n"),
			%% !!!
			%% Should send message to management terminal before close
			%% Please check which kind of message
			%% !!!
			closetcpsocket(Socket,"management terminal");
		Msg ->
			logmessage("Unknown data from management terminal - ~p - : ~p~n", [Socket,Msg]),
			logmessage("Close manamgement terminal socket~n"),
			%% !!!
			%% Should send message to management terminal before close
			%% Please check which kind of message
			%% !!!
			closetcpsocket(Socket,"management terminal")
 	after ?TERMINAL_TCP_RECEIVE_TIMEOUT ->
		logmessage("No data from management terminal - ~p - after ~p ms~n", [Socket,?TERMINAL_TCP_RECEIVE_TIMEOUT]),
		logmessage("Close management terminal socket - ~p~n", [Socket]),
		closetcpsocket(Socket,"management terminal")
    end.

processmanagementdata(Bin) ->
	Bin.

%%
%% If there is continous ?ACCEPT_ERROR_MAX_COUNT fails/exceptions, the server will be shutdown
%%
connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count) ->
	if
		Count > ?ACCEPT_ERROR_MAX_COUNT ->
			stop(),
			logmessage("Accept terminal fails continously ~p times and stop accepting~n",[?ACCEPT_ERROR_MAX_COUNT]),
			exit("Stop accepting terminal because of too many failures/exceptions~n");
		Count =< ?ACCEPT_ERROR_MAX_COUNT ->
			%% !!!
			%% Do we need timeout for accept here?
			%% It seems to be unnecessary.
			%% !!!
		    try	gen_tcp:accept(Listen) of
				{ok,Socket} ->
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,1) end),
					logmessage("Accept and current terminal socket : ~p~n", [Socket]),
		           	loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2);
				{error,Reason} ->
					[{acceptfailures,ErrorCount}] = ets:lookup(serverstatetable, acceptfailures),
					ets:insert(serverstatetable, {acceptfailures,ErrorCount+1}),
					logmessage("Accepting total failures/exceptions : ~p~n", [ErrorCount+1]),
					logmessagetryagain("Accepting failure : ~p~n",[Reason],Count),
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count+1) end)
			catch
				_:Why ->
					[{acceptfailures,ExceptionCount}] = ets:lookup(serverstatetable, acceptfailures),
					ets:insert(serverstatetable, {acceptfailures,ExceptionCount+1}),
					logmessage("Accepting total failures/exceptions : ~p~n", [ExceptionCount+1]),
					logmessagetryagain("Accepting exception : ~p~n",[Why],Count),
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count+1) end)
			end
	end.

%%
%% If server hasn't received an data from the terminal after ?TCP_RECEIVE_TIMEOUT ms, the socket of the terminal will be closed.
%%
loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2) ->
	receive
		{tcp,Socket,Bin} ->
			%% It is safe for the same terminal because each terminal is not allowed to report very frequenctly.
			%% The time interval is 60m which is needed to be checked with the planner.
			TimeStamp = calendar:now_to_local_time(erlang:now()),
			%% !!!
			%%TimeStamp = calendar:now_to_local_time(erlang:now()),
			%%dataprocessor:savesocketbin(true,Socket,Bin,TimeStamp),
			%% !!!
			%%io:format("Tcp server get from terminal = ~p~n",[Bin]),
			%%case is_binary(Bin) of
			%%	true ->
			%%		ok;
			%%	false ->
			%%		Str = binary_to_term(Bin),
			%%		io:format("Tcp server get from terminal (term) ~p~n",[Str])
			%%end,
			case httpservermessage(Bin) of
				true ->
		            HttpBin = dataprocessor:tcp2http(Bin),
		            %%io:format("Tcp server translate from terminal = ~p~n",[HttpBin]),
					%%case is_binary(HttpBin) of
					%%	true ->
					%%		ok;
					%%	false ->
					%%		HttpStr = binary_to_term(HttpBin),
					%%		io:format("Tcp server translate from terminal (term) ~p~n",[HttpStr])
					%%end,
					HttpMsgCount=ets:select_count(msg2httptable, [{{'$1','$2','$3'},[],[true]}]),
					logmessage("Total stored msg2http message count : ~p~n",[HttpMsgCount]),
					[{httpserverfailures,HttpFC}] = ets:lookup(serverstatetable, httpserverfailures),
					if
						HttpFC > ?CONNECT_HTTP_MAX_COUNT ->
							%% !!!
							%% We need to report this status to the terminal
							%% How do we define this message data?
							%% !!!
							logmessage("Http server has already met ~p continous failures~n",[?CONNECT_HTTP_MAX_COUNT]),
							logmessage("This message will be stored temperarily until the problem of the http server is fixed~n"),
							ets:insert(msg2httptable, {TimeStamp,Socket,HttpBin}),
							%% !!!
							%% We should save the un-reported message to the disk in another process.
							%% At the same time, we should clear the count in msg2httptable
							%% Otherwise, the msg2httptable table will be increased infinitely.
							%% !!!
							if
								HttpMsgCount > ?TO_HTTP_MAX_MESSAGE_COUNT ->
									ok;
								HttpMsgCount =< ?TO_HTTP_MAX_MESSAGE_COUNT ->
									ok
							end;
						HttpFC =< ?CONNECT_HTTP_MAX_COUNT ->
							%% We use another process is because we don't need the response from the http server
							spawn(fun()->connecthttpserver(HttpServer,Socket,TimeStamp,Bin) end)
					end;
				_ ->
					%% This message from the terminal doesn't need to be sent to the http server.
					ok
			end,
			JitMsgCount=ets:select_count(msg2jittable, [{{'$1','$2','$3'},[],[true]}]),
			logmessage("Total stored msg2jit message count : ~p~n",[JitMsgCount]),
			[{jitserverfailures,JitFC}] = ets:lookup(serverstatetable, jitserverfailures),
			if
				JitFC > ?CONNECT_JIT_MAX_COUNT ->
					%% !!!
					%% We need to report this status to the terminal
					%% How do we define this message data?
					%% !!!
					logmessage("The two jit servers has already met ~p continous failures~n",[?CONNECT_HTTP_MAX_COUNT]),
					logmessage("This message will be stored temperarily until the problem of the two jit servers is fixed~n"),
					ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
					%% !!!
					%% We should save the un-reported message to the disk in another process.
					%% At the same time, we should clear the count in msg2jittable
					%% Otherwise, the msg2jittable table will be increased infinitely.
					%% !!!
					if
						JitMsgCount > ?TO_JIT_MAX_MESSAGE_COUNT ->
							ok;
						JitMsgCount =< ?TO_JIT_MAX_MESSAGE_COUNT ->
							ok
					end;
				JitFC =< ?CONNECT_JIT_MAX_COUNT ->
					%% We must check which jit tcp sever we should use.
					[{usemastertcpserver,UseMaster}] = ets:lookup(serverstatetable, usemastertcpserver),
					case connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster,Socket,TimeStamp,Bin) of
						{ok, BinResp} ->
							connecttcpterminal(Socket,BinResp,1),
				 	        inet:setopts(Socket,[{active,once}]),
				            loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2);
						error ->
							logmessage("Both jit tcp servers error~n"),
							logmessage("Close terminal socket - ~p~n", [Socket]),
							%% !!!
							%% Should send message to terminal before close
							%% Please check which kind of message
							%% !!!
							closetcpsocket(Socket,"terminal")
					end
			end;
		{tcp_closed,Socket} ->
			logmessage("Terminal close socket - ~p~n", [Socket]);
		{tcp_error,Socket} ->
			logmessage("Terminal socket - ~p - error : ~p~n", [Socket,tcp_error]),
			logmessage("Close terminal socket - ~p~n", [Socket]),
			%% !!!
			%% Should send message to terminal before close
			%% Please check which kind of message
			%% !!!
			closetcpsocket(Socket,"terminal");
		Msg ->
			logmessage("Received unknown data from terminal socket - ~p : ~p~n", [Socket,Msg]),
			logmessage("Close terminal socket - ~p~n", [Socket]),
			%% !!!
			%% Should send message to terminal before close
			%% Please check which kind of message
			%% !!!
			closetcpsocket(Socket,"terminal")
 	after ?TERMINAL_TCP_RECEIVE_TIMEOUT ->
		logmessage("Cannot receive any data from terminal socket - ~p - after ~p ms~n", [Socket,?TERMINAL_TCP_RECEIVE_TIMEOUT]),
		logmessage("Close terminal socket - ~p~n", [Socket]),
		%% !!!
		%% Should send message to terminal before close
		%% Please check which kind of message
		%% !!!
		closetcpsocket(Socket,"terminal")
    end.
	
%%
%% Check this message from the terminal should be sent to the http server or not
%%
httpservermessage(Bin) ->
	Bin,
	true.

%%
%%post(URL, ContentType, Body) -> request(post, {URL, [], ContentType, Body}).
%%get(URL)                     -> request(get,  {URL, []}).
%%head(URL)                    -> request(head, {URL, []}).
%%
connecthttpserver(HttpServer,Socket,TimeStamp,Bin) ->
	[{httpserverfailures,HttpFC}] = ets:lookup(serverstatetable, httpserverfailures),
	%% !!!
	%% Please check the parameters of the method httpc:request(...)
	%% !!!
	ContentType = "text/json",
	Options = [{body_format,binary}],
	try httpc:request(post,{HttpServer,[],ContentType,Bin},[],Options) of
		{ok,_} ->
			%% !!!
			%% Http server is ok now.
			%% We should start another process to send the stored messages from the terminals to the http server.
			%% !!!
			spawn(fun()->connecthttpserverstored(HttpServer) end),
			ets:insert(serverstatetable, {httpserverfailures,0});
		{error,RequestReason} ->
			logmessage("Sending request to http server - ~p - failure : ~p~n",[HttpServer,RequestReason]),
			logmessage("Store the request : ~p:~p:~p~n",[TimeStamp,Socket,Bin]),
			%% !!!
			%% We need to report this status to the terminal
			%% How do we define this message data?
			%% !!!
			ets:insert(serverstatetable, {httpserverfailures,HttpFC+1}),
			ets:insert(msg2httptable, {TimeStamp,Socket,Bin})
	catch
		_:RequestWhy ->
			logmessage("Sending request to http server - ~p - exception : ~p~n",[HttpServer,RequestWhy]),
			logmessage("Store the request : ~p:~p:~p~n",[TimeStamp,Socket,Bin]),
			%% !!!
			%% We need to report this status to the terminal
			%% How do we define this message data?
			%% !!!
			ets:insert(serverstatetable, {httpserverfailures,HttpFC+1}),
			ets:insert(msg2httptable, {TimeStamp,Socket,Bin})
	end.
	%%%% Is it needed?
	%%%% It seems that if we use it, there will be some issue with the socket.
	%%%% Also I don't know whether inets:stop(httpc,self()) can work or not. 
	%%try inets:stop(httpc,self()) of
	%%	ok ->
	%%		logmessage("Stop http client~n");
	%%	{error,StopReason} ->
	%%		logmessage("Stop http client fails : ~p~n", [StopReason]),
	%%		logmessage("Ignore failure~n")
	%%catch
	%%	_:StopWhy ->
	%%		logmessage("Stop http client exception : ~p~n", [StopWhy]),
	%%		logmessage("Ignore exception~n")
	%%end.

%%
%% Send stored message from the terminal to the http server
%%
connecthttpserverstored(HttpServer) ->
	HttpServer,
	ok.

%%
%% The master tcp server will be first tried and if it fails, the slave tcpserver will be used.
%% If return error, it means both master and slave tcp servers are unavailable.
%% If any one of the two servers is ok, will return {ok,BinResp}
%%
connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster,Socket,TimeStamp,Bin) ->
	if
		UseMaster == true ->
			logmessage("Connect master jit tcp server - ~p:~p~n",[TcpServer,TcpPort]),
			case connectonetcpserver(TcpServer,TcpPort,Bin) of
				{ok,BinResp} ->
					{ok,BinResp};
				error ->
					logmessage("Connect master jit tcp server fails - ~p:~p~n",[TcpServer,TcpPort]),
					connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,false,Socket,TimeStamp,Bin)
			end;
		UseMaster == false ->
			logmessage("Connect slave jit tcp server - ~p:~p~n",[TcpServer2,TcpPort2]),
			case connectonetcpserver(TcpServer2,TcpPort2,Bin) of
				{ok,BinResp2} ->
					{ok,BinResp2};
				error ->
					logmessage("Connect slave jit tcp server fails - ~p:~p~n",[TcpServer2,TcpPort2]),
					logmessage("Store the request : ~p:~p:~p~n",[TimeStamp,Socket,Bin]),
					%% !!!
					%% We need to report this status to the terminal
					%% How do we define this message data?
					%% !!!
					[{jitserverfailures,JitFC}] = ets:lookup(serverstatetable, jitserverfailures),
					ets:insert(serverstatetable, {jitserverfailures,JitFC+1}),
					ets:insert(msg2jittable,{TimeStamp,Socket,Bin}),
					error
			end
	end.

connectonetcpserver(TcpServer,TcpPort,Bin) ->
    try gen_tcp:connect(TcpServer,TcpPort,[binary,{packet,0}]) of
        {ok,Socket} ->
			try gen_tcp:send(Socket,Bin) of
				ok ->
					receive
				        {tcp,Socket,BinResp} ->
							logmessage("Received data from jit tcp server socket - ~p - : ~p~n", [Socket,BinResp]),
							logmessage("Close jit tcp server socket - ~p~n", [Socket]),
							closetcpsocket(Socket,"jit tcp server"),
							{ok,BinResp};
						{tcp_closed,Socket} ->
							dataprocessor:logmessage("Jit tcp server close server socket - ~p~n", [Socket]),
							error;
						{tcp_error,Socket,Reason} ->
				            dataprocessor:logmessage("Jit tcp server socket - ~p - error : ~p~n", [Socket,Reason]),
							dataprocessor:logmessage("Close jit tcp server socket : ~p~n", [Socket]),
							closetcpsocket(Socket,"jit tcp server"),
							error;
						Msg ->
							dataprocessor:logmessage("Received unknown data from jit tcp server - ~p - : ~p~n", [Socket,Msg]),
							dataprocessor:logmessage("Close jit tcp server socket - ~p~n", [Socket]),
							closetcpsocket(Socket,"jit tcp server"),
							error
					after ?JIT_TCP_RECEIVE_TIMEOUT ->
						dataprocessor:logmessage("Cannot receive any data from jit tcp server - ~p - after ~p ms : ~p~n", [Socket,?JIT_TCP_RECEIVE_TIMEOUT]),
						dataprocessor:logmessage("Close jit tcp socket - ~p~n", [Socket]),
						closetcpsocket(Socket,"jit tcp server"),
						error
					end;
				{error,Reason} ->
					dataprocessor:logmessage("Send data to jit tcp server - ~p - fails : ~p~n",[Socket,Reason]),
					dataprocessor:logmessage("Close jit tcp server socket : ~p~n", [Socket]),
					closetcpsocket(Socket,"jit tcp server"),
					error
			catch
                _:SendWhy ->
					dataprocessor:logmessage("Send data to jit tcp server - ~p - exception : ~p~n",[Socket,SendWhy]),
					dataprocessor:logmessage("Close jit tcp server socket - ~p~n", [Socket]),
					closetcpsocket(Socket,"jit tcp server"),
					error
			end;
		{error,Reason} ->
			logmessage("Connect jit tcp server - ~p:~p - failure : ~p~n",[TcpServer,TcpPort,Reason]),
			error
	catch
        _:Why ->
			logmessage("Connect jit tcp server - ~p:~p - Exception : ~p~n",[TcpServer,TcpPort,Why]),
			error
	end.

%%
%% If the server cannot send message to the terminal, the message will be discard.
%% It is because the terminal should do the request again.
%%
connecttcpterminal(Socket,Bin,Count) ->
	connecttcpterminal(Socket,Bin,Count,false).
	
connecttcpterminal(Socket,Bin,Count,IsManagement) ->
	if
		IsManagement == true ->
			TermString = "management terminal";
		IsManagement == false ->
			TermString = "terminal"
	end,
	if
		Count > ?REPONSE_TERMINAL_MAX_COUNT ->
			dataprocessor:logmessage("Send data to " + TermString + " - ~p - fails continously ~p times~n",[Socket,?ACCEPT_ERROR_MAX_COUNT]),
			dataprocessor:logmessage("Gives up sending data to " + TermString + " - ~p~n",[Socket]),
			closetcpsocket(Socket,TermString);
		Count =< ?REPONSE_TERMINAL_MAX_COUNT ->
			try gen_tcp:send(Socket,Bin) of
				ok ->
					ok;
				{error,Reason} ->
					logmessagetryagain("Send data to " + TermString + " - ~p - fails : ~p~n",[Socket,Reason],Count),
					connecttcpterminal(Socket,Bin,Count+1)
			catch
		        _:Why ->
					logmessagetryagain("Send data to " + TermString + " - ~p - exception : ~p~n",[Socket,Why],Count),
					connecttcpterminal(Socket,Bin,Count+1)
			end
	end.

closetcpsocket(Socket,Who) ->
	try gen_tcp:close(Socket)
	catch
		_:Why ->
			logmessage("Close " + Who + " socket - ~p - exception : ~p~n", [Socket,Why]),
			logmessage("Ignore exception~n")
	end.

%% Each time when the server startup,
%% the saved old requests should first be processed.
processsavedrequests() ->
	ok.

logmessage(Format) ->
	dataprocessor:logmessage(Format,serverstatetable).

logmessage(Format,Data) ->
	dataprocessor:logmessage(Format,Data,serverstatetable).

%%logmessagetryagain(Format,Count) ->
%%	dataprocessor:logmessagetryagain(Format,Count,serverstatetable).

logmessagetryagain(Format,Data,Count) ->
	dataprocessor:logmessagetryagain(Format,Data,Count,serverstatetable).
