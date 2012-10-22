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

-define(ACCEPT_ERROR_MAX_COUNT,(3)).
%% Send the message from the terminal to the http server
-define(CONNECT_HTTP_MAX_COUNT,(3)).
%% Send the message from the terminal to the two jit servers
-define(CONNECT_JIT_MAX_COUNT,(3)).
%% Send the message from the jit server to the terminal
-define(REPONSE_TERMINAL_MAX_COUNT,(3)).
-define(TCP_RECEIVE_TIMEOUT,(30000)).

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

-export([start/0,start1/0,start2/0,startsystem/0,startsystem/5,stop/0]).

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

start1() ->
	startsystem("http://google.com/",?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT).

start2() ->
	startsystem("http://api.21com.com/",?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT).

start() ->
	startsystem(?HTTP_SERVER,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT).

startsystem() ->
	startsystem(?HTTP_SERVER,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT).

startsystem(HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2) ->
	init([]),
	processsavedrequests(),
	%% {active,once} can make the server safe in case of huge amount of requests.
	try gen_tcp:listen(?TERMINAL_LISTEN_PORT,[binary,{packet,0},{reuseaddr,true}, {active,once}]) of
	    {ok,Listen} ->
			logmessage("Server start~n"),
			spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,1) end);
	    {error,Reason} ->
			stop(),
			logmessage("Server start fails : ~p~n", [Reason]),
			logmessage("Exit~n"),
			exit(Reason)
	catch
		_:Why ->
			stop(),
			logmessage("Server start exception : ~p~n", [Why]),
			logmessage("Exit~n"),
			exit(Why)
	end,
	try gen_tcp:listen(?MANAGEMENT_LISTEN_PORT,[binary,{packet,0},{reuseaddr,true}, {active,once}]) of
	    {ok,ListenMan} ->
			logmessage("Server management start~n"),
			spawn(fun() -> connectmanagement(ListenMan,1) end);
	    {error,ReasonMan} ->
			stop(),
			logmessage("Server management start fails : ~p~n", [ReasonMan]),
			logmessage("Exit~n"),
			exit(ReasonMan)
	catch
		_:WhyMan ->
			stop(),
			logmessage("Server management start exception : ~p~n", [WhyMan]),
			logmessage("Exit~n"),
			exit(WhyMan)
	end.

stop() ->
	ets:delete(tcphttpstatetable),
	ets:delete(tcpclienttable),
	ets:delete(tcpclienthttptable),
	ok.

%%
%% Local Functions
%%

%%
%% What is the purpose of the table?
%% Is it necessary that we keep each request from the tcp client or response from the http server?
%%
init([]) ->
	ets:new(tcphttpstatetable,[set,named_table,{read_concurrency,true},{write_concurrency,true}]),
	%% When released, displaylog should be false.
	ets:insert(tcphttpstatetable,{displaylog,true}),
	ets:insert(tcphttpstatetable,{usemastertcpserver,true}),
	ets:insert(tcphttpstatetable,{tcpserverfailures,0}),
	ets:insert(tcphttpstatetable,{httpserverfailures,0}),
	ets:new(jitserverresponsetable,[set,named_table,{read_concurrency,true},{write_concurrency,true}]),
	ets:new(tcpclienttable,[set,named_table,{read_concurrency,true},{write_concurrency,true}]),
	ets:new(tcpclienthttptable,[duplicate_bag,named_table,{read_concurrency,true},{write_concurrency,true}]).

%%
%% Management, for example, stop server, enaable/disable display, switch jit master/slave and etc.
%%
connectmanagement(Listen,Count) ->
	if
		Count > ?ACCEPT_ERROR_MAX_COUNT ->
			stop(),
			logmessage("Server accept management terminal fails continously ~p times~n",[?ACCEPT_ERROR_MAX_COUNT]),
			logmessage("Exit~n"),
			exit("Server accept management terminal fails continously ~p times and exits~n",[?ACCEPT_ERROR_MAX_COUNT]);
		Count =< ?ACCEPT_ERROR_MAX_COUNT ->
		    try	gen_tcp:accept(Listen) of
				{ok,Socket} ->
		           	spawn(fun() -> connectmanagement(Listen,1) end),
					logmessage("Current management socket : ~p~n", [Socket]),
		           	loopmanagement(Socket);
				{error,Reason} ->
					logmessagetryagain("Accepting management failure : ~p~n",[Reason],Count),
		           	spawn(fun() -> connectmanagement(Listen,Count+1) end)
			catch
				_:Why ->
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
			connecttcpterminal(Socket,BinResp,1);
		{tcp_closed,Socket} ->
			logmessage("Management terminal close socket - ~p~n", [Socket]);
		{tcp_error,Socket} ->
			logmessage("Management terminal socket - ~p - error :  ~p~n", [Socket,tcp_error]),
			logmessage("Server close management terminal socket - ~p~n", [Socket]),
			%% !!!
			%% Should send message to management terminal before close
			%% Please check which kind of message
			%% !!!
			closetcpsocket(Socket,"management terminal");
		Msg ->
			logmessage("Server received unknown message from management terminal - ~p - : ~p~n", [Socket,Msg]),
			logmessage("Server close manamgement terminal socket - ~p~n", [Socket]),
			%% !!!
			%% Should send message to management terminal before close
			%% Please check which kind of message
			%% !!!
			closetcpsocket(Socket,"management terminal")
 	after ?TCP_RECEIVE_TIMEOUT ->
		logmessage("Server cannot receive any message from management terminal - ~p - after ~p ms~n", [Socket,?TCP_RECEIVE_TIMEOUT]),
		logmessage("Server close management terminal socket - ~p~n", [Socket]),
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
			logmessage("Server accept terminal fails continously ~p times~n",[?ACCEPT_ERROR_MAX_COUNT]),
			logmessage("Exit~n"),
			exit("Server accept terminal fails continously ~p times and exits~n",[?ACCEPT_ERROR_MAX_COUNT]);
		Count =< ?ACCEPT_ERROR_MAX_COUNT ->
			%% !!!
			%% Do we need timeout for accept here?
			%% !!!
		    try	gen_tcp:accept(Listen) of
				{ok,Socket} ->
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,1) end),
					logmessage("Current terminal socket : ~p~n", [Socket]),
					{Address,Port} = safepeername(Socket),
					logmessage("Current terminal socket : ~p:~p~n", [Address,Port]),
		           	loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2);
				{error,Reason} ->
					logmessagetryagain("Accepting failure : ~p~n",[Reason],Count),
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count+1) end)
			catch
				_:Why ->
					logmessagetryagain("Accepting exception : ~p~n",[Why],Count),
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count+1) end)
			end
	end.

safepeername(Socket) ->
	try inet:peername(Socket) of
		{ok,{Address,Port}} ->
			{Address,Port};
		{error,PnReason} ->
			logmessage("Convert terminal socket - ~p - failure : ~p~n",[Socket,PnReason]),
			logmessage("Use {0.0.0.0}:0 instead~n"),
			%% !!!
			%% Is it the correct format
			%% !!!
			{"0.0.0.0",0}
	catch
		_:PnWhy ->
			logmessage("Convert terminal socket - ~p - exception : ~p~n",[Socket,PnWhy]),
			logmessage("Use 0.0.0.0:0 instead~n"),
			%% !!!
			%% Is it the correct format
			%% !!!
			{"0.0.0.0",0}
	end.

%%
%% If server hasn't received an data from the terminal after ?TCP_RECEIVE_TIMEOUT ms, the socket of the terminal will be closed.
%%
loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2) ->
	{Address,Port} = safepeername(Socket),
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
					[{httpserverfailures,HttpFC}] = ets:lookup(tcphttpstatetable, httpserverfailures),
					if
						HttpFC > ?CONNECT_HTTP_MAX_COUNT ->
							%% !!!
							%% We need to report this status to the terminal
							%% How do we define this message data?
							%% !!!
							logmessage("Http server has met 10 continous failures~n"),
							logmessage("This message will be stored temperarily until the problem of the http server is fixed~n"),
							ets:insert(tcpclienthttptable, {TimeStamp,Address,Port,HttpBin}),
							HttpMsgCount=ets:select_count(tcpclienthttptable, [{{'$1','$2'},[],[true]}]),
							if
								HttpMsgCount > ?TO_HTTP_MAX_MESSAGE_COUNT ->
									%% !!!
									%% We should save the un-reported message to the disk in another process.
									%% At the same time, we should clear the count in tcpclienthttptable
									%% !!!
									ok;
								HttpMsgCount =< ?TO_HTTP_MAX_MESSAGE_COUNT ->
									ok
							end;
						HttpFC =< ?CONNECT_HTTP_MAX_COUNT ->
							%% We use another process is because we don't need the response from the http server
							spawn(fun()->connecthttpserver(HttpServer,Address,Port,TimeStamp,Bin) end)
					end;
				_ ->
					%% This message from the terminal doesn't need to be sent to the http server.
					ok
			end,
			[{tcpserverfailures,TcpFC}] = ets:lookup(tcphttpstatetable, tcpserverfailures),
			if
				TcpFC > ?CONNECT_JIT_MAX_COUNT ->
					%% !!!
					%% We need to report this status to the terminal
					%% How do we define this message data?
					%% !!!
					logmessage("The two jit servers has met 10 continous failures~n"),
					logmessage("This message will be stored temperarily until the problem of the two jit servers is fixed~n"),
					ets:insert(tcpclienttable, {TimeStamp,Address,Port,Bin}),
					TermMsgCount=ets:select_count(tcpclienttable, [{{'$1','$2'},[],[true]}]),
					if
						TermMsgCount > ?TO_JIT_MAX_MESSAGE_COUNT ->
							%% !!!
							%% We should save the un-reported message to the disk in another process.
							%% At the same time, we should clear the count in tcpclienttable
							%% !!!
							ok;
						TermMsgCount =< ?TO_JIT_MAX_MESSAGE_COUNT ->
							ok
					end;
				TcpFC =< ?CONNECT_JIT_MAX_COUNT ->
					%% We must check which jit tcp sever we should use.
					[{usemastertcpserver,UseMaster}] = ets:lookup(tcphttpstatetable, usemastertcpserver),
					case connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster,Bin) of
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
			logmessage("Received unknown message from terminal socket - ~p : ~p~n", [Socket,Msg]),
			logmessage("Close terminal socket - ~p~n", [Socket]),
			%% !!!
			%% Should send message to terminal before close
			%% Please check which kind of message
			%% !!!
			closetcpsocket(Socket,"terminal")
 	after ?TCP_RECEIVE_TIMEOUT ->
		logmessage("Cannot receive any data from terminal socket - ~p - after ~p ms~n", [Socket,?TCP_RECEIVE_TIMEOUT]),
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
connecthttpserver(HttpServer,Address,Port,TimeStamp,Bin) ->
	[{httpserverfailures,Value}] = ets:lookup(tcphttpstatetable, httpserverfailures),
	%% Can this call be ignored?
	%% It seems that this call is necessary.
	try inets:start() of
		ok ->
			%% !!!
			%% Please check the parameters of the method httpc:request(...)
			%% !!!
			ContentType = "text/json",
			Options = [{body_format,binary}],
			try httpc:request(post,{HttpServer,[],ContentType,Bin},[],Options) of
				{ok,_} ->
					%% Http server is ok now.
					%% We should start another process to send the stored messages from the terminals to the http server.
					spawn(fun()->connecthttpserverstored(HttpServer) end),
					ets:insert(tcphttpstatetable, {httpserverfailures,0});
				{error,RequestReason} ->
					logmessage("Sending request to http server - ~p - failure : ~p~n",[HttpServer,RequestReason]),
					logmessage("Store the request : ~p:~p:~p~p~n",[TimeStamp,Address,Port,Bin]),
					ets:insert(tcphttpstatetable, {httpserverfailures,Value+1}),
					ets:insert(tcpclienthttptable, {TimeStamp,Address,Port,Bin})
			catch
				_:RequestWhy ->
					logmessage("Sending request to http server - ~p - exception : ~p~n",[HttpServer,RequestWhy]),
					logmessage("Store the request : ~p:~p:~p~p~n",[TimeStamp,Address,Port,Bin]),
					ets:insert(tcphttpstatetable, {httpserverfailures,Value+1}),
					ets:insert(tcpclienthttptable, {TimeStamp,Address,Port,Bin})
			end,
			%% Is it needed?
			%% It seems that if we use it, there will be some issue with the socket.
			%% Also I don't know whether inets:stop(httpc,self()) can work or not. 
			try inets:stop(httpc,self()) of
				ok ->
					ok;
				{error,StopReason} ->
					dataprocessor:logmessage("Server stop http client fails : ~p~n", [StopReason]),
					dataprocessor:logmessage("Force stop~n")
			catch
				_:StopWhy ->
					dataprocessor:logmessage("Server stop http client exception : ~p~n", [StopWhy]),
					dataprocessor:logmessage("Force stop~n")
			end;
		{error,Reason} ->
			logmessage("Server start http client fails : ~p~n", [Reason]),
			logmessage("Store the request : ~p:~p:~p~p~n",[TimeStamp,Address,Port,Bin]),
			ets:insert(tcphttpstatetable, {httpserverfailures,Value+1}),
			ets:insert(tcpclienthttptable, {TimeStamp,Address,Port,Bin})
	catch
		_:Why ->
			logmessage("Server start http client exception : ~p~n", [Why]),
			logmessage("Store the request : ~p:~p:~p~p~n",[TimeStamp,Address,Port,Bin]),
			ets:insert(tcphttpstatetable, {httpserverfailures,Value+1}),
			ets:insert(tcpclienthttptable, {TimeStamp,Address,Port,Bin})
	end.

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
connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster,Bin) ->
	if
		UseMaster == true ->
			dataprocessor:logmessage("Server connect master jit tcp server - ~p:~p~n",[TcpServer,TcpPort]),
			case connectonetcpserver(TcpServer,TcpPort,Bin) of
				{ok,BinResp} ->
					{ok,BinResp};
				error ->
					dataprocessor:logmessage("Server connect master jit tcp server fails - ~p:~p~n",[TcpServer,TcpPort]),
					dataprocessor:logmessage("Server then connect slave jit tcp server - ~p:~p~n",[TcpServer2,TcpPort2]),
					connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,false,Bin)
			end;
		UseMaster == false ->
			dataprocessor:logmessage("Server connect slave jit tcp server - ~p:~p~n",[TcpServer2,TcpPort2]),
			case connectonetcpserver(TcpServer2,TcpPort2,Bin) of
				{ok,BinResp2} ->
					{ok,BinResp2};
				error ->
					dataprocessor:logmessage("Server connect slave jit tcp server fails - ~p:~p~n",[TcpServer,TcpPort]),
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
							logmessage("Server received data from jit tcp server socket - ~p - : ~p~n", [Socket,BinResp]),
							logmessage("Server close jit tcp server socket - ~p~n", [Socket]),
							closetcpsocket(Socket,"jit tcp server"),
							{ok,BinResp};
						{tcp_closed,Socket} ->
							dataprocessor:logmessage("Jit tcp server close server socket - ~p~n", [Socket]),
							error;
						{tcp_error,Socket,Reason} ->
				            dataprocessor:logmessage("Jit tcp server socket - ~p - error : ~p~n", [Socket,Reason]),
							dataprocessor:logmessage("Server close jit tcp server socket : ~p~n", [Socket]),
							closetcpsocket(Socket,"jit tcp server"),
							error;
						Msg ->
							dataprocessor:logmessage("Received unknown message from jit tcp server - ~p - : ~p~n", [Socket,Msg]),
							dataprocessor:logmessage("Server close jit tcp server socket - ~p~n", [Socket]),
							closetcpsocket(Socket,"jit tcp server"),
							error
					after ?TCP_RECEIVE_TIMEOUT ->
						dataprocessor:logmessage("Cannot receive any message from jit tcp server - ~p - after ~p ms : ~p~n", [Socket,?TCP_RECEIVE_TIMEOUT]),
						dataprocessor:logmessage("Server close jit tcp socket - ~p~n", [Socket]),
						closetcpsocket(Socket,"jit tcp server"),
						error
					end;
				{error,Reason} ->
					dataprocessor:logmessage("Server send data to jit tcp server - ~p - fails : ~p~n",[Socket,Reason]),
					dataprocessor:logmessage("Server close jit tcp server socket : ~p~n", [Socket]),
					closetcpsocket(Socket,"jit tcp server"),
					error
			catch
                _:SendWhy ->
					dataprocessor:logmessage("Server send data to jit tcp server - ~p - exception : ~p~n",[Socket,SendWhy]),
					dataprocessor:logmessage("Server close jit tcp server socket - ~p~n", [Socket]),
					closetcpsocket(Socket,"jit tcp server"),
					error
			end;
		{error,Reason} ->
			logmessage("Server connect jit tcp server - ~p:~p - failure : ~p~n",[TcpServer,TcpPort,Reason]),
			error
	catch
        _:Why ->
			logmessage("Server connect jit tcp server - ~p:~p - Exception : ~p~n",[TcpServer,TcpPort,Why]),
			error
	end.

connecttcpterminal(Socket,Bin,Count) ->
	if
		Count > ?REPONSE_TERMINAL_MAX_COUNT ->
			dataprocessor:logmessage("Server send data to terminal - ~p - fails continously ~p times~n",[Socket,?ACCEPT_ERROR_MAX_COUNT]),
			dataprocessor:logmessage("Server gives up send data to terminal - ~p~n",[Socket]),
			closetcpsocket(Socket,"terminal");
		Count =< ?REPONSE_TERMINAL_MAX_COUNT ->
			try gen_tcp:send(Socket,Bin) of
				ok ->
					ok;
				{error,Reason} ->
					logmessagetryagain("Server send data to terminal - ~p - fails : ~p~n",[Socket,Reason],Count),
					connecttcpterminal(Socket,Bin,Count+1)
			catch
		        _:Why ->
					logmessagetryagain("Server send data to terminal - ~p - exception : ~p~n",[Socket,Why],Count),
					connecttcpterminal(Socket,Bin,Count+1)
			end
	end.

closetcpsocket(Socket,Who) ->
	try gen_tcp:close(Socket)
	catch
		_:Why ->
			logmessage("Server close " + Who + " socket - ~p - exception : ~p~n", [Socket,Why]),
			logmessage("Force close~n")
	end.

%% Each time when the server startup,
%% the saved old requests should first be processed.
processsavedrequests() ->
	ok.

logmessage(Format) ->
	dataprocessor:logmessage(Format,tcphttpstatetable).

logmessage(Format,Data) ->
	dataprocessor:logmessage(Format,Data,tcphttpstatetable).

%%logmessagetryagain(Format,Count) ->
%%	dataprocessor:logmessagetryagain(Format,Count,tcphttpstatetable).

logmessagetryagain(Format,Data,Count) ->
	dataprocessor:logmessagetryagain(Format,Data,Count,tcphttpstatetable).
