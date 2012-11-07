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

-include("common.hrl").
-include("manterm.hrl").

-import(dataprocessor).

%%
%% Definitions
%%

%%
%% Exported Functions
%%

%%
%% For test purpose
%%
-export([start0/0,start0/1,start0/2]).
-export([start1/0,start1/1,start1/2]).
-export([start2/0,start2/1,start2/2]).
-export([start3/0,start3/1,start3/2]).
-export([startn/3]).
%%
%% Release version
%%
-export([start/0,start/1,start/2,start/9,stop/0]).

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
	start0(true,0).
start0(DisplayLog) ->
	start0(DisplayLog,0).
start0(DisplayLog,LogLevel) ->
	startn("http://127.0.0.1",DisplayLog,LogLevel).
start1() ->
	start1(true,0).
start1(DisplayLog) ->
	start1(DisplayLog,0).
start1(DisplayLog,LogLevel) ->
	startn("http://localhost",DisplayLog,LogLevel).
start2() ->
	start2(true,0).
start2(DisplayLog) ->
	start2(DisplayLog,0).
start2(DisplayLog,LogLevel) ->
	startn("http://google.com",DisplayLog,LogLevel).
start3() ->
	start(true,0).
start3(DisplayLog) ->
	start3(DisplayLog,0).
start3(DisplayLog,LogLevel) ->
	startn("http://api.21com.com",DisplayLog,LogLevel).
startn(HttpServer,DisplayLog,LogLevel) ->
	start(HttpServer,?HTTP_PROCESSES_COUNT,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,?JIT_PROCESSES_COUNT,DisplayLog,LogLevel).

start() ->
	start(false).
start(DisplayLog) ->
	start(DisplayLog,?MSG_LEVEL_ERROR).
start(DisplayLog,LogLevel) ->
	start(?HTTP_SERVER_NOPORT,?HTTP_PROCESSES_COUNT,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,?JIT_PROCESSES_COUNT,DisplayLog,LogLevel).
start(HttpServer,HttpInstCount,TcpServer,TcpPort,TcpServer2,TcpPort2,TcpInstCount,DisplayLog,LogLevel) ->
	init(DisplayLog,LogLevel),
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
	try gen_tcp:listen(?TERM_LISTEN_PORT,[binary,{packet,0},{reuseaddr,true}, {active,once}]) of
	    {ok,Listen} ->
			loginfo("Server started~n"),
			spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,1) end);
	    {error,Reason} ->
			stop(),
			logerror("Server start fails : ~p and exits~n", [Reason]),
			exit(Reason)
	catch
		_:Why ->
			stop(),
			logerror("Server start exception : ~p and exits~n", [Why]),
			exit(Why)
	end,
	try gen_tcp:listen(?MT_LISTEN_PORT,[binary,{packet,0},{reuseaddr,true}, {active,once}]) of
	    {ok,ListenMan} ->
			loginfo("Server management started~n"),
			spawn(fun() -> connectmanagement(ListenMan,1) end);
	    {error,ReasonMan} ->
			stop(),
			logerror("Server management start fails : ~p and exits~n", [ReasonMan]),
			exit(ReasonMan)
	catch
		_:WhyMan ->
			stop(),
			logerror("Server management start exception : ~p and exits~n", [WhyMan]),
			exit(WhyMan)
	end,
	try inets:start() of
		ok ->
			loginfo("Server http client started~n");
		{error,ReasonInets} ->
			logerror("Server http client fails : ~p and exits~n",[ReasonInets]),
			exit(ReasonInets)
	catch
		_:WhyInets ->
			logerror("Http client exception : ~p and exits~n",[WhyInets]),
			exit(WhyInets)
	end,
	try starthttpprocesses(HttpServer,HttpInstCount) of
		{ok,HttpCount} ->
			loginfo(string:concat(integer_to_list(HttpCount), " http processes started~n"));
		{error,ReasonHttp} ->
			logerror("Http processes fails : ~p and exits~n",[ReasonHttp]),
			exit(ReasonHttp)
	catch
		_:WhyHttp ->
			logerror("Http processes exception : ~p and exits~n",[WhyHttp]),
			exit(WhyHttp)
	end,
	try starthttpdispatcher(HttpServer) of
		true ->
			loginfo("Http dispatcher started~n")
	catch
		_:WhyDispatcher ->
			logerror("Http dispacteher exception : ~p and exits~n",[WhyDispatcher]),
			exit(WhyDispatcher)
	end,
	TcpInstCount.
	%%try startjitprocesses(TcpInstCount) of
	%%	{ok,JitCount} ->
	%%		loginfo(string:concat(integer_to_list(JitCount), " jit processes started~n"));
	%%	{error,ReasonJit} ->
	%%		logerror("Jit processes fails : ~p and exits~n",[ReasonJit]),
	%%		exit(ReasonJit)
	%%catch
	%%	_:WhyJit ->
	%%		logerror("Jit processes exception : ~p and exits~n",WhyJit),
	%%		exit(WhyJit)
	%%end.
			
%%
%% Start Http processes pool
%% Parameter : HttpServer - ...
%%             HttpInstCount - ...
%% Output : {ok,Count} Actual processes count
%%          {error,Why}
%%
starthttpprocesses(HttpServer,HttpInstCount) ->
	if
		HttpInstCount > 0 ->
			try startsinglehttpprocess(HttpServer) of
				_ ->
					starthttpprocesses(HttpServer,HttpInstCount-1)
			catch
				_:Why ->
					{error,Why}
			end;
		HttpInstCount =< 0 ->
			Count = ets:select_count(httpprocesstable, [{{'$1'},[],[true]}]),
			{ok,Count}
	end.

%%
%% httpprocesstable
%% Pid,Socket,Timstamp,Msg
%%
startsinglehttpprocess(HttpServer) ->
	Pid = spawn(fun() -> singlehttpprocess(HttpServer) end),
	ets:insert(httpprocesstable, {Pid}),
	ets:insert(normalhttpprocesstable, {Pid}).

singlehttpprocess(HttpServer) ->
	receive
		{Pid,Msg} ->
			Pid,
			{TimeStamp,Socket,HttpBin} = Msg,
			case connecthttpserver(HttpServer,TimeStamp,Socket,HttpBin) of
				ok ->
					singlehttpprocess(HttpServer);
				{error,Reason} ->
					logerror("Http process ~p error : ~p~n",[self(),Reason]),
					ets:delete(normalhttpprocesstable, self())
			end;
		stop ->
			loginfo("Http process ~p stopped~n", self()),
			ets:delete(normalhttpprocesstable, self())
	end.

starthttpdispatcher(HttpServer) ->
	Pid = spawn(fun() -> httpdispatcherprocinst(HttpServer,0) end),
	TimeStamp = calendar:now_to_local_time(erlang:now()),
	ets:insert(serverstatetable, {httpdispatcher,Pid,TimeStamp}).

httpdispatcherprocinst(HttpServer,Index) ->
	if
		Index >= ?HTTP_DISPATCHER_TIME_INTERVAL_MS ->
			TimeStamp = calendar:now_to_local_time(erlang:now()),
			ets:insert(serverstatetable, {httpdispatcher,self(),TimeStamp}),
			NewIndex = 0;
		Index < ?HTTP_DISPATCHER_TIME_INTERVAL_MS ->
			NewIndex = Index + 1
	end,
	NormHttpProcCount = ets:select_count(normalhttpprocesstable, [{{'$1'},[],[true]}]),
	if
		NormHttpProcCount < 1 ->
			logerror("No active http connection and http dispatcher stops.~n"),
			ets:insert(serverstatetable, {httpdispatcher,-1,-1});
		NormHttpProcCount >= 1 ->
			if
				NormHttpProcCount < ?CONNECT_HTTP_WARN_COUNT ->
					logwarning("The count of active http connections are =< ~p~n",[?CONNECT_HTTP_WARN_COUNT]);
				NormHttpProcCount >= ?CONNECT_HTTP_WARN_COUNT ->
					ok
			end,
			HttpProcCount = ets:select_count(httpprocesstable, [{{'$1'},[],[true]}]),
			if
				HttpProcCount < 1 ->
					loginfo("No idle http connection and http dispatcher waits.~n"),
					timer:sleep(1);
				HttpProcCount >= 1 ->
					if
						HttpProcCount < ?CONNECT_HTTP_WARN_COUNT ->
							logwarning("The count of idle http connections are =< ~p~n",[?CONNECT_HTTP_WARN_COUNT]);
						HttpProcCount >= ?CONNECT_HTTP_WARN_COUNT ->
							ok
					end,
					case ets:first(msg2httptable) of
						'$end_of_table' ->
							timer:sleep(1);
						Key ->
							Msges = ets:lookup(msg2httptable, Key),
							ets:delete(msg2httptable, Key),
							Pid = ets:first(httpprocesstable),
							%% !!!
							%% Disable this loginfo because the data will be too many
							%% !!!
							%%loginfo("Current http process id : ~p~n",Pid),
							ets:delete(httpprocesstable, Pid),
							httpdispatcherprocess(HttpServer,Pid,Msges)
					end
			end,
			httpdispatcherprocinst(HttpServer,NewIndex)
	end.

httpdispatcherprocess(HttpServer,Pid,Msges) ->
	spawn(fun() -> dohttpdispatcherprocess(HttpServer,Pid,Msges) end).

dohttpdispatcherprocess(HttpServer,Pid,Msges) ->
	case Msges of
		[] ->
			ets:insert(httpprocesstable, {Pid});
		_ ->
			[First|Others] = Msges,
			Pid!{self(),First},
			dohttpdispatcherprocess(HttpServer,Pid,Others)
	end.

%%
%%post(URL, ContentType, Body) -> request(post, {URL, [], ContentType, Body}).
%%get(URL)                     -> request(get,  {URL, []}).
%%head(URL)                    -> request(head, {URL, []}).
%%
connecthttpserver(HttpServer,TimeStamp,Socket,HttpBin) ->
	%% !!!
	%% Please check the parameters of the method httpc:request(...)
	%% !!!
	TimeStamp,
	Socket,
	ContentType = "text/json",
	Options = [{body_format,binary}],
	try httpc:request(post,{HttpServer,[],ContentType,HttpBin},[],Options) of
		{ok,_} ->
			ok;
		{error,Reason} ->
			logerror("Requesting http server fail : ~p~n",[Reason]),
			{error,Reason}
	catch
		_:Why ->
			logerror("Requesting http server exception : ~p~n",[Why]),
			{error,Why}
	end.

%%
%% Not necessary currently
%%
%%startjitprocesses(TcpInstCount) ->
%%	{ok,TcpInstCount}.

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
	ets:delete(serverlogtable),
	ets:delete(msg2terminaltable),
	ets:delete(maninstancetable),
	ets:delete(terminstancetable),
	%%ets:delete(jitprocesstable),
	%% Send stop to all http processes before delete httpprocesstable
	ets:delete(httpprocesstable),
	ets:delete(normalhttpprocesstable),
	ok.

%%
%% Local Functions
%%

%%
%% What is the purpose of the table?
%% Is it necessary that we keep each request from the tcp client or response from the http server?
%%
%%
init(DisplayLog,LogLevel) ->
	ets:new(serverstatetable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:insert(serverstatetable,{displaylog,DisplayLog}),
	ets:insert(serverstatetable,{oridisplaylog,DisplayLog}),
	ets:insert(serverstatetable,{usemasterjit,true}),
	ets:insert(serverstatetable,{masterjitfail,0}),
	ets:insert(serverstatetable,{jitserverfail,0}),
	%%ets:insert(serverstatetable,{httpserverfail,0}),
	ets:insert(serverstatetable,{accepttermcontfail,0}),
	ets:insert(serverstatetable,{accepttermtotalfail,0}),
	ets:insert(serverstatetable,{acceptmancontfail,0}),
	ets:insert(serverstatetable,{acceptmantotalfail,0}),
	ets:insert(serverstatetable,{logserverlevel,LogLevel}),
	ets:insert(serverstatetable,{orilogserverlevel,LogLevel}),
	ets:insert(serverstatetable,{httpdispatcher,-1,-1}),
	ets:insert(serverstatetable,{httpprocessmin,?HTTP_PROCESSES_MIN_COUNT}),
	ets:insert(serverstatetable,{httpprocessmax,?HTTP_PROCESSES_MAX_COUNT}),
	ets:new(msg2terminaltable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(msg2jittable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(maninstancetable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(terminstancetable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(msg2httptable,[duplicate_bag,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(serverlogtable,[duplicate_bag,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(httpprocesstable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(normalhttpprocesstable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]).

%%
%% Management, for example, stop server, enaable/disable display, switch jit master/slave and etc.
%%
connectmanagement(Listen,Count) ->
	if
		Count > ?ACCEPT_ERROR_TOTAL_MAX ->
			%% !!!
			%% How to tell the management terminal?
			%% !!!
			logerror("Accept man-term fails ~p times~n",[?ACCEPT_ERROR_TOTAL_MAX]);
		Count =< ?ACCEPT_ERROR_TOTAL_MAX ->
			if
				Count > ?ACCEPT_ERROR_CONT_MAX ->
					%% !!!
					%% How to tell the management terminal?
					%% !!!
					logerror("Accept man-term fails continously ~p times~n",[?ACCEPT_ERROR_CONT_MAX]);
				Count =< ?ACCEPT_ERROR_CONT_MAX ->
					%% !!!
					%% Do we need timeout for accept here?
					%% It seems to be unnecessary.
					%% !!!
					[{acceptmancontfail,ContCount}] = ets:lookup(serverstatetable, acceptmancontfail),
					[{acceptmantotalfail,TotalCount}] = ets:lookup(serverstatetable, acceptmantotalfail),
				    try	gen_tcp:accept(Listen) of
						{ok,Socket} ->
				           	spawn(fun() -> connectmanagement(Listen,1) end),
							ets:insert(serverstatetable, {acceptmancontfail,0}),
							%%[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
							%%ets:insert(serverstatetable, {mantermcount,ManCount+1}),
							insertmansocket(Socket),
							%%loginfo("Current man-term (~p)~n", [Socket]),
				           	loopmanagement(Socket);
						{error,Reason} ->
							ets:insert(serverstatetable, {acceptmancontfail,ContCount+1}),
							ets:insert(serverstatetable, {acceptmantotalfail,TotalCount+1}),
							logerror("Accepting man-term fails (cont ~p/total ~p) : ~p~n",[ContCount+1,TotalCount+1,Reason]),
				           	spawn(fun() -> connectmanagement(Listen,Count+1) end)
					catch
						_:Why ->
							ets:insert(serverstatetable, {acceptmancontfail,ContCount+1}),
							ets:insert(serverstatetable, {acceptmantotalfail,TotalCount+1}),
							logerror("Accepting man-term exceptions (cont ~p/total ~p) : ~p~n",[ContCount+1,TotalCount+1,Why]),
				           	spawn(fun() -> connectmanagement(Listen,Count+1) end)
					end
			end
	end.

loopmanagement(Socket) ->
	receive
		{tcp,Socket,Bin} ->
			%% Update the latest commnucation time between the man term and the server
			insertmansocket(Socket),
			%% !!!
			%% Do management here, for example, stop server, enaable/disable display, switch jit master/slave and etc.
			%% !!!
			%%loginfo("Data from man-term",Bin),
			BinResp = processmanagementdata(Bin),
			%%loginfo("Data to man-term",BinResp),
			case connectmanterm(Socket,BinResp) of
				ok ->
					inet:setopts(Socket,[{active,once}]),
					loopmanagement(Socket);
				{error,_} ->
					logerror("Close man-term socket~n"),
					%% !!!
					%% Should server send message to management terminal before close?
					%% If so, please check which kind of message
					%% Does tcp_error mean that server cannot send data to management terminal?
					%% !!!
					closetcpsocket(Socket,"man-term"),
					%%[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
					%%ets:insert(serverstatetable, {mantermcount,ManCount-1})
					deletemansocket(Socket)
			end;
		{tcp_closed,Socket} ->
			%%logerror("Man-term close socket (~p)~n", [Socket]),
			%%[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
			%%ets:insert(serverstatetable, {mantermcount,ManCount-1});
			deletemansocket(Socket);
		{tcp_error,Socket} ->
			logerror("Man-term socket (~p) tcp_error~n", [Socket]),
			logerror("Close man-term socket~n"),
			%% !!!
			%% Should server send message to management terminal before close?
			%% If so, please check which kind of message
			%% Does tcp_error mean that server cannot send data to management terminal?
			%% !!!
			closetcpsocket(Socket,"man-term"),
			%%[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
			%%ets:insert(serverstatetable, {mantermcount,ManCount-1});
			deletemansocket(Socket);
		Msg ->
			logerror("Unknown server state for man-term socket (~p) : ~p~n", [Socket,Msg]),
			logerror("Close man-term socket~n"),
			%% !!!
			%% Should server send message to management terminal before close?
			%% If so, please check which kind of message
			%% !!!
			connectmanterm(Socket,?UNKNWON_SOCKET_STATE),
			closetcpsocket(Socket,"man-term"),
			%%[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
			%%ets:insert(serverstatetable, {mantermcount,ManCount-1})
			deletemansocket(Socket)
 	after ?MT_TCP_RECEIVE_TIMEOUT ->
		logerror("No data from man-term (~p) after ~p ms~n", [Socket,?MT_TCP_RECEIVE_TIMEOUT]),
		logerror("Close man-term socket~n"),
		connectmanterm(Socket,?UNKNWON_TERMINAL_STATE),
		closetcpsocket(Socket,"man-term"),
		%%[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
		%%ets:insert(serverstatetable, {mantermcount,ManCount-1})
		deletemansocket(Socket)
	end.

%%
%% Header (2 byte : 2 * 8)
%% Sub Header (4 bytes : 4 * 8)
%% Body
%%
%% Call doprocessmanagementdata with try...catch
%%
processmanagementdata(Bin) ->
	try doprocessmanagementdata(Bin) of
		BinResp ->
			BinResp
	catch
		_:Why ->
			string:concat(?MT_MAN_SERVER_FAILURE,Why)
	end.

%%
%% Header (2 byte : 2 * 8)
%% Sub Header (4 bytes : 4 * 8)
%% Body
%%
%% Please use processmanagementdata(Bin)
%%
doprocessmanagementdata(Bin) ->
	case is_binary(Bin) of
		true ->
			BinStr = binary_to_list(Bin),
			IsStr = true;
		false ->
			case is_list(Bin) of
				true ->
					BinStr = Bin,
					IsStr = true;
				false ->
					BinStr = ?MT_UNK_REQ_ERR,
					IsStr = false
			end
	end,
	if
		IsStr == false ->
			string:concat(?MT_UNK_REQ_ERR,BinStr);
		IsStr == true ->
			Len = length(BinStr),
			if
				Len < ?MT_MSG_MIN_LEN ->
					string:concat(?MT_UNK_REQ_ERR,BinStr);
				Len >= ?MT_MSG_MIN_LEN ->
					if
						Len == ?MT_MSG_MIN_LEN ->
							Header = BinStr,
							Body = "";
						Len > ?MT_MSG_MIN_LEN ->
							Header = lists:sublist(BinStr, ?MT_MSG_MIN_LEN),
							Body = lists:sublist(BinStr, ?MT_MSG_MIN_LEN+1, Len-?MT_MSG_MIN_LEN)
					end,
					case Header of
						?MT_UNK_REQ ->
							string:concat(?MT_UNK_REQ_ERR,BinStr);
						?MT_CLR_ACC_MT_CONT_FAIL->
							ets:insert(serverstatetable, {acceptmancontfail,0}),
							?MT_CLR_ACC_MT_CONT_FAIL_OK;
						?MT_CLR_ACC_MT_TOTAL_FAIL->
							ets:insert(serverstatetable, {acceptmantotalfail,0}),
							?MT_CLR_ACC_MT_TOTAL_FAIL_OK;
						?MT_CLR_ACC_TERM_CONT_FAIL ->
							ets:insert(serverstatetable, {accepttermcontfail,0}),
							?MT_CLR_ACC_TERM_CONT_FAIL_OK;
						?MT_CLR_ACC_TERM_TOTAL_FAIL ->
							ets:insert(serverstatetable, {accepttermtotalfail,0}),
							?MT_CLR_ACC_TERM_TOTAL_FAIL_OK;
						?MT_CLR_ALL_2HTTP ->
							ets:delete_all_objects(msg2httptable),
							?MT_CLR_ALL_2HTTP_OK;
						?MT_CLR_ALL_2JIT ->
							ets:delete_all_objects(msg2jittable),
							?MT_CLR_ALL_2JIT_OK;
						?MT_CLR_ALL_2TERM ->
							ets:delete_all_objects(msg2terminaltable),
							?MT_CLR_ALL_2TERM_OK;
						?MT_CLR_BOTH_JIT_FAIL ->
							ets:insert(serverstatetable, {jitserverfail,0}),
							?MT_CLR_BOTH_JIT_FAIL_OK;
						?MT_CLR_MASTER_JIT_FAIL ->
							ets:insert(serverstatetable, {masterjitfail,0}),
							?MT_CLR_MASTER_JIT_FAIL_OK;
						?MT_QRY_ACC_MT_CONT_FAIL ->
							[{acceptmancontfail,Value}] = ets:lookup(serverstatetable, acceptmancontfail),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ACC_MT_CONT_FAIL_OK, Str);
						?MT_QRY_ACC_MT_TOTAL_FAIL ->
							[{acceptmantotalfail,Value}] = ets:lookup(serverstatetable, acceptmantotalfail),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ACC_MT_TOTAL_FAIL_OK, Str);
						?MT_QRY_ACC_TERM_CONT_FAIL ->
							[{accepttermcontfail,Value}] = ets:lookup(serverstatetable, accepttermcontfail),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ACC_TERM_CONT_FAIL_OK, Str);
						?MT_QRY_ACC_TERM_TOTAL_FAIL ->
							[{accepttermtotalfail,Value}] = ets:lookup(serverstatetable, accepttermtotalfail),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ACC_TERM_TOTAL_FAIL_OK, Str);
						?MT_QRY_ALL_2HTTP ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_2HTTP_ERR;
						?MT_QRY_ALL_2HTTP_CLR ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_2HTTP_CLR_ERR;
						?MT_QRY_ALL_2HTTP_COUNT ->
							Value = ets:select_count(msg2httptable, [{{'$1','$2','$3'},[],[true]}]),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ALL_2HTTP_COUNT_OK, Str);
						?MT_QRY_ALL_2JIT ->		
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_2JIT_ERR;
						?MT_QRY_ALL_2JIT_CLR ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_2JIT_CLR_ERR;
						?MT_QRY_ALL_2JIT_COUNT ->
							Value = ets:select_count(msg2jittable, [{{'$1','$2','$3'},[],[true]}]),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ALL_2JIT_COUNT_OK, Str);
						?MT_QRY_ALL_2TERM ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_2TERM_ERR;
						?MT_QRY_ALL_2TERM_CLR ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_2TERM_CLR_ERR;
						?MT_QRY_ALL_2TERM_COUNT ->
							%% !!!
							%% Need further job here because we don't know the message format in msg2terminaltable
							%% !!!
							Value = ets:select_count(msg2terminaltable, [{{'$1','$2','$3'},[],[true]}]),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ALL_2TERM_COUNT_OK, Str);
						?MT_QRY_ALL_LOG ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_LOG_ERR;
						?MT_QRY_ALL_LOG_CLR ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_LOG_CLR_ERR;
						?MT_QRY_ALL_LOG_COUNT ->
							Value = ets:select_count(serverlogtable, [{{'$1','$2','$3'},[],[true]}]),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ALL_LOG_COUNT_OK, Str);
						?MT_CLR_ALL_LOG ->
							ets:delete_all_objects(serverlogtable),
							?MT_CLR_ALL_LOG_OK;
						?MT_QRY_ALL_STATES ->
							case getallstates() of
								{ok,States} ->
									string:concat(?MT_QRY_ALL_STATES_OK, States);
								{error,Why} ->
									string:concat(?MT_QRY_ALL_STATES_ERR, Why)
							end;
						?MT_QRY_BOTH_JIT_FAIL ->
							[{jitserverfail,Value}] = ets:lookup(serverstatetable, jitserverfail),	
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_BOTH_JIT_FAIL_OK, Str);
						?MT_QRY_DISPLAY_LOG_STATE ->
							[{displaylog,Value}] = ets:lookup(serverstatetable, displaylog),
							case Value of
								true ->
									Str = ("1");
								_ ->
									Str = ("0")
							end,
							string:concat(?MT_QRY_DISPLAY_LOG_STATE_OK, Str);
						?MT_QRY_LOG_LEVEL ->
							[{logserverlevel,Value}] = ets:lookup(serverstatetable, logserverlevel),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_LOG_LEVEL_OK, Str);
						?MT_QRY_MASTER_JIT_FAIL ->
							[{masterjitfail,Value}] = ets:lookup(serverstatetable, masterjitfail),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_MASTER_JIT_FAIL_OK, Str);
						?MT_QRY_USE_MASTER_STATE ->
							[{usemasterjit,Value}] = ets:lookup(serverstatetable, usemasterjit),
							case Value of
								true ->
									Str = ("1");
								_ ->
									Str = ("0")
							end,
							string:concat(?MT_QRY_USE_MASTER_STATE_OK, Str);
						?MT_RST_ALL_STATES ->
							case resetallstates() of
								ok ->
									?MT_RST_ALL_STATES_OK;
								{error,Why} ->
									string:concat(?MT_RST_ALL_STATES_ERR, Why)
							end;
						?MT_SET_DISPLAY_LOG_STATE ->
							case Body of
								 "1" ->
									ets:insert(serverstatetable, {displaylog,true}),
									?MT_SET_DISPLAY_LOG_STATE_OK;
								"0" ->
									ets:insert(serverstatetable, {displaylog,false}),
									?MT_SET_DISPLAY_LOG_STATE_OK;
								_ ->
									string:concat(?MT_UNK_MT_DATA, Body)
							end;
						?MT_SET_LOG_LEVEL ->
							case Body of
								 "0" ->
									ets:insert(serverstatetable, {logserverlevel,0}),
									?MT_SET_LOG_LEVEL_OK;
								"1" ->
									ets:insert(serverstatetable, {logserverlevel,1}),
									?MT_SET_LOG_LEVEL_OK;
								"2" ->
									ets:insert(serverstatetable, {logserverlevel,2}),
									?MT_SET_LOG_LEVEL_OK;
								_ ->
									string:concat(?MT_UNK_MT_DATA, Body)
							end;
						?MT_SET_USE_MASTER_STATE ->
							case Body of
								 "1" ->
									ets:insert(serverstatetable, {usemasterjit,true}),
									?MT_SET_USE_MASTER_STATE_OK;
								"0" ->
									ets:insert(serverstatetable, {usemasterjit,false}),
									?MT_SET_USE_MASTER_STATE_OK;
								_ ->
									string:concat(?MT_UNK_MT_DATA, Body)
							end;
						?MT_QRY_ALL_MT ->
							%% !!!
							%% Need further job here
							%% !!!
							ManTerms = ets:select(maninstancetable, [{{'$1','$2','$3','$4'},[],[{{'$2','$3','$4'}}]}]),
							Str = getallmanterm(ManTerms),
							string:concat(?MT_QRY_ALL_MT_OK, Str);
						?MT_QRY_ALL_MT_COUNT ->
							%% !!!
							%% Need further job here because we don't know the message format in msg2terminaltable
							%% !!!
							Value = ets:select_count(maninstancetable, [{{'$1','$2','$3','$4'},[],[true]}]),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ALL_MT_COUNT_OK, Str);
						?MT_QRY_ORI_DISPLAY_LOG_STATE ->
							[{oridisplaylog,Value}] = ets:lookup(serverstatetable, oridisplaylog),
							case Value of
								true ->
									Str = ("1");
								_ ->
									Str = ("0")
							end,
							string:concat(?MT_QRY_ORI_DISPLAY_LOG_STATE_OK, Str);
						?MT_QRY_ORI_LOG_LEVEL ->
							[{orilogserverlevel,Value}] = ets:lookup(serverstatetable, orilogserverlevel),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ORI_LOG_LEVEL_OK, Str);
						?MT_QRY_ALL_TERM ->
							%% !!!
							%% Need further job here
							%% !!!
							Terms = ets:select(terminstancetable, [{{'$1','$2','$3','$4'},[],[{{'$2','$3','$4'}}]}]),
							Str = getallmanterm(Terms),
							string:concat(?MT_QRY_ALL_TERM_OK, Str);
						?MT_QRY_ALL_TERM_COUNT ->
							%% !!!
							%% Need further job here because we don't know the message format in msg2terminaltable
							%% !!!
							Value = ets:select_count(terminstancetable, [{{'$1','$2','$3','$4'},[],[true]}]),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_ALL_TERM_COUNT_OK, Str);
						?MT_QRY_NORMAL_HTTP_PROC_COUNT ->
							%%[{httpserverfail,Value}] = ets:lookup(serverstatetable, httpserverfail),
							%%Str=integer_to_list(Value),
							%%string:concat(?MT_QRY_HTTP_FAIL_OK, Str);
							?MT_QRY_NORMAL_HTTP_PROC_COUNT_ERR;
						?MT_QRY_IDLE_HTTP_PROC_COUNT ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_IDLE_HTTP_PROC_COUNT_ERR;
						?MT_QRY_HTTP_PROC_MAX_COUNT ->
							?MT_QRY_HTTP_PROC_MAX_COUNT_ERR;
						?MT_QRY_HTTP_PROC_WARN_COUNT ->
							?MT_QRY_HTTP_PROC_WARN_COUNT_ERR;
						?MT_SET_HTTP_PROC_MAX_COUNT ->
							?MT_SET_HTTP_PROC_MAX_COUNT_ERR;
						?MT_SET_HTTP_PROC_WARN_COUNT ->
							?MT_SET_HTTP_PROC_WARN_COUNT_ERR
					end
			end
	end.

getallmanterm(Terms) ->
	case Terms of
		[] ->
			"";
		_ ->
			[First|Others] = Terms,
			{Address,Port,TimeStamp} = First,
			{{Year,Month,Day},{Hour,Minute,Second}} = TimeStamp,
			S1 = string:concat(inet_parse:ntoa(Address), ","),
			S2 = string:concat(S1, integer_to_list(Port)),
			S3 = string:concat(S2, ","),
			S4 = string:concat(S3, lists:flatten(io_lib:format('~4..0b-~2..0b-~2..0b', [Year, Month, Day]))),
			S5 = string:concat(S4, " "),
			S6 = string:concat(S5, lists:flatten(io_lib:format('~2..0b:~2..0b:~2..0b', [Hour, Minute, Second]))),
			case Others of
				[] ->
					S6;
				_ ->
					S7 = string:concat(S6, ";"),
					string:concat(S7, getallmanterm(Others))
			end
	end.

getallstates() ->
	try dogetallstates() of
		{ok,States} ->
			{ok,States}
	catch
		_:Why ->
			{error,Why}
	end.

dogetallstates() ->
	[{displaylog,DisplayLog}] = ets:lookup(serverstatetable,displaylog),
	case DisplayLog of
		true ->
			S1 = "DisplayLog:1";
		_ ->
			S1 = "DisplayLog:0"
	end,
	[{usemasterjit,UseMaster}] = ets:lookup(serverstatetable,usemasterjit),
	case UseMaster of
		true ->
			S2 = string:concat(S1, ";UseMaster:1");
		_ ->
			S2 = string:concat(S1, ";UseMaster:0")
	end,
	[{masterjitfail,MasterFC}] = ets:lookup(serverstatetable,masterjitfail),
	S30 = string:concat(S2, ";MasterFC:"),
	S3 = string:concat(S30, integer_to_list(MasterFC)),
	[{jitserverfail,JitFC}] = ets:lookup(serverstatetable,jitserverfail),
	S40 = string:concat(S3, ";JitFC:"),
	S4 = string:concat(S40, integer_to_list(JitFC)),
	HttpIdleCount = ets:select_count(httpprocesstable, [{{'$1'},[],[true]}]),
	S50 = string:concat(S4, ";HttpIdleCount:"),
	S5 = string:concat(S50, integer_to_list(HttpIdleCount)),
	[{accepttermcontfail,AccTermCFC}] = ets:lookup(serverstatetable,accepttermcontfail),
	S60 = string:concat(S5, ";AccTermCFC:"),
	S6 = string:concat(S60, integer_to_list(AccTermCFC)),
	[{accepttermtotalfail,AccTermTFC}] = ets:lookup(serverstatetable,accepttermtotalfail),
	S70 = string:concat(S6, ";AccTermTFC:"),
	S7 = string:concat(S70, integer_to_list(AccTermTFC)),
	[{acceptmancontfail,AccMCFC}] = ets:lookup(serverstatetable,acceptmancontfail),
	S80 = string:concat(S7, ";AccMCFC:"),
	S8 = string:concat(S80, integer_to_list(AccMCFC)),
	[{acceptmantotalfail,AccMTFC}] = ets:lookup(serverstatetable,acceptmantotalfail),
	S90 = string:concat(S8, ";AccMTFC:"),
	S9 = string:concat(S90, integer_to_list(AccMTFC)),
	[{logserverlevel,LogLevel}] = ets:lookup(serverstatetable,logserverlevel),
	S100 = string:concat(S9, ";LogLevel:"),
	S10 = string:concat(S100, integer_to_list(LogLevel)),
	Msg2JitCount = ets:select_count(msg2jittable, [{{'$1','$2','$3'},[],[true]}]),
	S110 = string:concat(S10, ";Msg2JitCount:"),
	S11 = string:concat(S110, integer_to_list(Msg2JitCount)),
	Msg2HttpCount = ets:select_count(msg2httptable, [{{'$1','$2','$3'},[],[true]}]),
	S120 = string:concat(S11, ";Msg2HttpCount:"),
	S12 = string:concat(S120, integer_to_list(Msg2HttpCount)),
	LogCount = ets:select_count(serverlogtable, [{{'$1','$2','$3'},[],[true]}]),
	S130 = string:concat(S12, ";LogCount:"),
	S13 = string:concat(S130, integer_to_list(LogCount)),
	Msg2TermCount = ets:select_count(msg2terminaltable, [{{'$1','$2','$3'},[],[true]}]),
	S140 = string:concat(S13, ";Msg2TermCount:"),
	S14 = string:concat(S140, integer_to_list(Msg2TermCount)),
	MTermInstCount = ets:select_count(maninstancetable, [{{'$1','$2','$3','$4'},[],[true]}]),
	S150= string:concat(S14, ";MTermInstCount:"),
	S15 = string:concat(S150, integer_to_list(MTermInstCount)),
	[{orilogserverlevel,OriLogLevel}] = ets:lookup(serverstatetable,orilogserverlevel),
	S160 = string:concat(S15, ";OriLogLevel:"),
	S16 = string:concat(S160, integer_to_list(OriLogLevel)),
	[{oridisplaylog,OriDisplayLog}] = ets:lookup(serverstatetable,oridisplaylog),
	case OriDisplayLog of
		true ->
			S17 = string:concat(S16, ";OriDisplayLog:1");
		_ ->
			S17 = string:concat(S16, ";OriDisplayLog:0")
	end,
	TermInstCount = ets:select_count(terminstancetable, [{{'$1','$2','$3','$4'},[],[true]}]),
	S180 = string:concat(S17, ";TermInstCount:"),
	S18 = string:concat(S180, integer_to_list(TermInstCount)),
	[{httpdispatcher,_,TimeStamp}] = ets:lookup(serverstatetable,httpdispatcher),
	{{Year,Month,Day},{Hour,Minute,Second}} = TimeStamp,
	S190 = string:concat(S18, ";HttpDispatcher:"),
	S191 = string:concat(S190, lists:flatten(io_lib:format('~4..0b-~2..0b-~2..0b', [Year, Month, Day]))),
	S192 = string:concat(S191, " "),
	S19 = string:concat(S192, lists:flatten(io_lib:format('~2..0b:~2..0b:~2..0b', [Hour, Minute, Second]))),
	HttpAvailableCount = ets:select_count(normalhttpprocesstable, [{{'$1'},[],[true]}]),
	S200 = string:concat(S19, ";HttpAvailableCount:"),
	S20 = string:concat(S200, integer_to_list(HttpAvailableCount)),
	[{httpprocessmin,HttpMin}] = ets:lookup(serverstatetable,httpprocessmin),
	S210 = string:concat(S20, ";HttpMin:"),
	S21 = string:concat(S210, integer_to_list(HttpMin)),
	[{httpprocessmax,HttpMax}] = ets:lookup(serverstatetable,httpprocessmax),
	S220 = string:concat(S21, ";HttpMax:"),
	S22 = string:concat(S220, integer_to_list(HttpMax)),
	{ok,S22}.	

resetallstates() ->
	try doresetallstates() of
		ok ->
			ok
	catch
		_:Why ->
			{error,Why}
	end.

doresetallstates() ->
	[{oridisplaylog,OriDisplayLog}] = ets:lookup(serverstatetable,oridisplaylog),
	ets:insert(serverstatetable,{displaylog,OriDisplayLog}),
	ets:insert(serverstatetable,{usemasterjit,true}),
	ets:insert(serverstatetable,{masterjitfail,0}),
	ets:insert(serverstatetable,{jitserverfail,0}),
	ets:insert(serverstatetable,{accepttermcontfail,0}),
	ets:insert(serverstatetable,{accepttermtotalfail,0}),
	ets:insert(serverstatetable,{acceptmancontfail,0}),
	ets:insert(serverstatetable,{acceptmantotalfail,0}),
	[{orilogserverlevel,OriLogLevel}] = ets:lookup(serverstatetable,orilogserverlevel),
	ets:insert(serverstatetable,{logserverlevel,OriLogLevel}),
	ets:delete_all_objects(msg2terminaltable),
	ets:delete_all_objects(msg2jittable),
	%%ets:delete_all_objects(maninstancetable),
	ets:delete_all_objects(msg2httptable),
	ets:delete_all_objects(serverlogtable),
	ok.

%%
%% If there is continous ?ACCEPT_ERROR_MAX_COUNT fails/exceptions, the server will be shutdown
%%
connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count) ->
	if
		Count > ?ACCEPT_ERROR_TOTAL_MAX ->
			%% !!!
			%% How to tell the management terminal?
			%% !!!
			logerror("Accept term fails ~p times~n",[?ACCEPT_ERROR_TOTAL_MAX]);
		Count =< ?ACCEPT_ERROR_TOTAL_MAX ->
			if
				Count > ?ACCEPT_ERROR_CONT_MAX ->
					%% !!!
					%% How to tell the management terminal?
					%% !!!
					logerror("Accept term fails continously ~p times~n",[?ACCEPT_ERROR_CONT_MAX]);
				Count =< ?ACCEPT_ERROR_CONT_MAX ->
					%% !!!
					%% Do we need timeout for accept here?
					%% It seems to be unnecessary.
					%% !!!
					[{accepttermcontfail,ContCount}] = ets:lookup(serverstatetable, accepttermcontfail),
					[{accepttermtotalfail,TotalCount}] = ets:lookup(serverstatetable, accepttermtotalfail),
				    try	gen_tcp:accept(Listen) of
						{ok,Socket} ->
				           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,1) end),
							ets:insert(serverstatetable, {accepttermcontfail,0}),
							%%[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
							%%ets:insert(serverstatetable, {termcount,TermCount+1}),
							inserttermsocket(Socket),
							%%loginfo("Current term (~p)~n", [Socket]),
				           	loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2);
						{error,Reason} ->
							ets:insert(serverstatetable, {accepttermcontfail,ContCount+1}),
							ets:insert(serverstatetable, {accepttermtotalfail,TotalCount+1}),
							logerror("Accepting term fails (cont ~p/total ~p) : ~p~n",[ContCount+1,TotalCount+1,Reason]),
				           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count+1) end)
					catch
						_:Why ->
							ets:insert(serverstatetable, {accepttermcontfail,ContCount+1}),
							ets:insert(serverstatetable, {accepttermtotalfail,TotalCount+1}),
							logerror("Accepting term exceptions (cont ~p/total ~p) : ~p~n",[ContCount+1,TotalCount+1,Why]),
				           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count+1) end)
					end
			end
	end.

%%
%% If server hasn't received an data from the terminal after ?TCP_RECEIVE_TIMEOUT ms, the socket of the terminal will be closed.
%%
loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2) ->
	receive
		{tcp,Socket,Bin} ->
			%% Update the latest commnucation time between the term and the server
			inserttermsocket(Socket),
			%% It is safe for the same terminal because each terminal is not allowed to report very frequenctly.
			%% The time interval is 60m which is needed to be checked with the planner.
			TimeStamp = calendar:now_to_local_time(erlang:now()),
			%%loginfo("Data from term",Bin),
			case httpservermessage(Bin) of
				true ->
		            HttpBin = dataprocessor:tcp2http(Bin),
					%%loginfo("Data to http server : ~p~n",HttpBin),
					HttpMsgCount=ets:select_count(msg2httptable, [{{'$1','$2','$3'},[],[true]}]),
					if
						HttpMsgCount > ?TO_HTTP_WARN_MESSAGE_COUNT -> %% Should these data be saved and the msg2httptable be cleared?
							logwarning("The count of msg2http reaches the warning number : ~p~n",[?TO_HTTP_WARN_MESSAGE_COUNT]);
						HttpMsgCount > ?TO_HTTP_MAX_MESSAGE_COUNT -> %% Should these data be saved and the msg2httptable be cleared?
							logerror("The count of msg2http reaches the max number : ~p~n",[?TO_HTTP_MAX_MESSAGE_COUNT]);
						HttpMsgCount =< ?TO_HTTP_WARN_MESSAGE_COUNT ->
							ok
					end,
					%%loginfo("Already stored msg2http message count : ~p~n",[HttpMsgCount]),
					NormalHttpProcCount=ets:select_count(normalhttpprocesstable, [{{'$1'},[],[true]}]),
					if
						NormalHttpProcCount < 1 ->
							logerror("No active http connection.~n"),
							HttpError = string:concat(?MT_HTTP_FAILURE, "No active http connection"),
							connectterm(Socket,HttpError),
							deletetermsocket(Socket),
							closetcpsocket(Socket,"term");
						NormalHttpProcCount >= 1 ->
							if
								NormalHttpProcCount < ?CONNECT_HTTP_WARN_COUNT ->
									logwarning("The count of active http connections are =< ~p~n",[?CONNECT_HTTP_WARN_COUNT]);
								NormalHttpProcCount >= ?CONNECT_HTTP_WARN_COUNT ->
									ok
							end,
							ets:insert(msg2httptable, {TimeStamp,Socket,HttpBin}),
							%%ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
							doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin)
					end;
				false ->
					NormalHttpProcCount=ets:select_count(normalhttpprocesstable, [{{'$1'},[],[true]}]),
					if
						NormalHttpProcCount < 1 ->
							logerror("No active http connection.~n"),
							HttpError = string:concat(?MT_HTTP_FAILURE, "No active http connection"),
							connectterm(Socket,HttpError),
							deletetermsocket(Socket),
							closetcpsocket(Socket,"term");
						NormalHttpProcCount >= 1 ->
							if
								NormalHttpProcCount < ?CONNECT_HTTP_WARN_COUNT ->
									logwarning("The count of active http connections are =< ~p~n",[?CONNECT_HTTP_WARN_COUNT]);
								NormalHttpProcCount >= ?CONNECT_HTTP_WARN_COUNT ->
									ok
							end,
							%%ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
							doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin)
					end
			end;
		{tcp_closed,Socket} ->
			%%logerror("Term close socket (~p)~n", [Socket]),
			%%[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
			%%ets:insert(serverstatetable, {termcount,TermCount-1});
			deletetermsocket(Socket);
		{tcp_error,Socket} ->
			logerror("Term socket (~p) tcp_error~n", [Socket]),
			%% !!!
			%% Should server send message to terminal before close?
			%% If so, please check which kind of message
			%% Does tcp_error mean that server cannot send data to terminal?
			%% !!!
			logerror("Close term socket (~p)~n", [Socket]),
			deletetermsocket(Socket),
			closetcpsocket(Socket,"term");
			%%[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
			%%ets:insert(serverstatetable, {termcount,TermCount-1});
		Msg ->
			logerror("Unknown server state for term socket (~p) : ~p~n", [Socket,Msg]),
			%% !!!
			%% Should server send message to terminal before close?
			%% If so, please check which kind of message
			%% !!!
			logerror("Close term socket (~p)~n", [Socket]),
			connectterm(Socket,?UNKNWON_SOCKET_STATE),
			%%[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
			%%ets:insert(serverstatetable, {termcount,TermCount-1})
			deletetermsocket(Socket),
			closetcpsocket(Socket,"term")
 	after ?TERM_TCP_RECEIVE_TIMEOUT ->
		logerror("No data from term (~p) after ~p ms~n", [Socket,?TERM_TCP_RECEIVE_TIMEOUT]),
		connectterm(Socket,?UNKNWON_TERMINAL_STATE),
		logerror("Close term socket (~p)~n", [Socket]),
		deletetermsocket(Socket),
		closetcpsocket(Socket,"term")
		%%[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
		%%ets:insert(serverstatetable, {termcount,TermCount-1})
		
    end.
	
%%
%% Check this message from the terminal should be sent to the http server or not
%%
httpservermessage(Bin) ->
	Bin,
	true.

doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin) ->
	[{jitserverfail,JitFC}] = ets:lookup(serverstatetable, jitserverfail),
	if
		JitFC > ?CONNECT_JIT_MAX_COUNT ->
			%% !!!
			%% We need to report this status to the terminal
			%% How do we define this message data?
			%% !!!
			logerror("~p continous failures in both jit servers and msg2jit will be stored~n",[?CONNECT_JIT_MAX_COUNT]),
			ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
			JitMsgCount=ets:select_count(msg2jittable, [{{'$1','$2','$3'},[],[true]}]),
			%%loginfo("Already stored msg2jit message count : ~p~n",[JitMsgCount]),
			if
				JitMsgCount > ?TO_JIT_MAX_MESSAGE_COUNT ->  %% Should these data be saved and the msg2jittable be cleared?
					ok;
				JitMsgCount =< ?TO_JIT_MAX_MESSAGE_COUNT ->
					ok
			end,
			%% !!!
			%% Should send message to terminal before close
			%% Please check which kind of message
			%% !!!
			connectterm(Socket,?MT_JIT_FAILURE),
			%%[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
			%%ets:insert(serverstatetable, {termcount,TermCount-1});
			deletetermsocket(Socket),
			closetcpsocket(Socket,"term");
		JitFC =< ?CONNECT_JIT_MAX_COUNT ->
			%% We must check which jit tcp sever we should use.
			[{usemasterjit,UseMaster}] = ets:lookup(serverstatetable, usemasterjit),
			case connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster,Socket,TimeStamp,Bin) of
				{ok, BinResp} ->
					%%loginfo("Data from jit server : ~p~n",BinResp),
					case connectterm(Socket,BinResp) of
						ok ->
				 	        inet:setopts(Socket,[{active,once}]),
				            loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2);
						{error,_} ->
							logerror("Close term socket and store msg2jit~n"),
							ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
							deletetermsocket(Socket),
							closetcpsocket(Socket,"term")
							%%[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
							%%ets:insert(serverstatetable, {termcount,TermCount-1})
					end;
				{error,Reason} ->
					logerror("Both jit servers error : ~p~n",Reason),
					logerror("Close term socket and save msg2jit~n"),
					ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
					%% !!!
					%% Should send message to terminal before close
					%% Please check which kind of message
					%% !!!
					connectterm(Socket,?MT_JIT_FAILURE),
					deletetermsocket(Socket),
					closetcpsocket(Socket,"term")
					%%[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
					%%ets:insert(serverstatetable, {termcount,TermCount-1})
			end
	end.

%%
%% The master tcp server will be first tried and if it fails, the slave tcpserver will be used.
%% If return error, it means both master and slave tcp servers are unavailable.
%% If any one of the two servers is ok, will return {ok,BinResp}
%%
connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster,Socket,TimeStamp,Bin) ->
	if
		UseMaster == true ->
			%%loginfo("Connect master~n"),
			[{masterjitfail,MJitFC}] = ets:lookup(serverstatetable, masterjitfail),
			case connectonetcpserver(TcpServer,TcpPort,Bin) of
				{ok,BinResp} ->
					%% !!!
					%% Since master is ok, send stored msg2http to it.
					%% !!!
					ets:insert(serverstatetable, {masterjitfail,0}),
					connecttcpserverstored(TcpServer,TcpPort,TcpServer2,TcpPort2,true),
					{ok,BinResp};
				{error,Reason} ->
					logerror("Master fails : ~p~n",Reason),
					logerror("Try slave~n"),
					ets:insert(serverstatetable, {masterjitfail,MJitFC+1}),
					connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,false,Socket,TimeStamp,Bin)
			end;
		UseMaster == false ->
			%%loginfo("Connect slave jit server~n"),
			case connectonetcpserver(TcpServer2,TcpPort2,Bin) of
				{ok,BinResp2} ->
					%% !!!
					%% Since slave is ok, send stored msg2http to it.
					%% !!!
					connecttcpserverstored(TcpServer,TcpPort,TcpServer2,TcpPort2,false),
					{ok,BinResp2};
				{error,Reason2} ->
					logerror("Slave jit server fails and store msg2jit~n"),
					%% !!!
					%% We need to report this status to the terminal
					%% How do we define this message data?
					%% !!!
					[{jitserverfail,JitFC}] = ets:lookup(serverstatetable, jitserverfail),
					ets:insert(serverstatetable, {jitserverfail,JitFC+1}),
					ets:insert(msg2jittable,{TimeStamp,Socket,Bin}),
					{error,Reason2}
			end
	end.

connecttcpserverstored(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster) ->
	TcpServer,
	TcpPort,
	TcpServer2,
	TcpPort2,
	UseMaster,
	ok.

connectonetcpserver(TcpServer,TcpPort,Bin) ->
    try gen_tcp:connect(TcpServer,TcpPort,[binary,{packet,0}]) of
        {ok,Socket} ->
			try gen_tcp:send(Socket,Bin) of
				ok ->
					receive
				        {tcp,Socket,BinResp} ->
							closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
							{ok,BinResp};
						{tcp_closed,Socket} ->
							logerror("Jit server close socket ~p:~p (~p)~n", [TcpServer,TcpPort,Socket]),
							{error,"JIT server close socket."};
						{tcp_error,Socket,Reason} ->
				            logerror("Jit server socket ~p:~p (~p) error : ~p~n", [TcpServer,TcpPort,Socket,Reason]),
							logerror("Close jit server socket~n"),
							closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
							{error,Reason};
						Msg ->
							logerror("Unknown server state for jit server socket ~p:~p (~p) : ~p~n", [TcpServer,TcpPort,Socket,Msg]),
							logerror("Close jit server socket~n"),
							closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
							{error,Msg}
					after ?JIT_TCP_RECEIVE_TIMEOUT ->
						logerror("No data from jit server ~p:~p (~p) after ~p ms~n", [TcpServer,TcpPort,Socket,?JIT_TCP_RECEIVE_TIMEOUT]),
						logerror("Close jit server socket~n"),
						closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
						{error,"JIT server timeout in response"}
					end;
				{error,Reason} ->
					logerror("Send data to jit server ~p:~p (~p) fails : ~p~n",[TcpServer,TcpPort,Socket,Reason]),
					logerror("Close jit server socket~n"),
					closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
					{error,Reason}
			catch
                _:Why ->
					logerror("Send data to jit tcp server (~p) exception : ~p~n",[Socket,Why]),
					logerror("Close jit server socket~n"),
					closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
					{error,Why}
			end;
		{error,Reason} ->
			logerror("Connect jit server (~p:~p) fail : ~p~n",[TcpServer,TcpPort,Reason]),
			{error,Reason}
	catch
        _:Why ->
			logerror("Connect jit tcp server (~p:~p) exception : ~p~n",[TcpServer,TcpPort,Why]),
			{error,Why}
	end.

%%
%% Socket :
%% Bin :
%% [SendBinary : false]
%% [IsManagement : true]
%%
%% ok | {error,Reason}
%%
connectmanterm(Socket,Bin) ->
	connectmanterm(Socket,Bin,false).

%%
%% Socket :
%% Bin :
%% SendBinary :
%% [IsManagement : true]
%%
%% ok | {error,Reason}
%%
connectmanterm(Socket,Bin,SendBinary) ->
	connectterminal(Socket,Bin,SendBinary,true).

%%
%% Socket :
%% Bin :
%% [SendBinary : true]
%% [IsManagement : false]
%%
%% ok | {error,Reason}
%%
connectterm(Socket,Bin) ->
	connectterm(Socket,Bin,true).

%%
%% Socket :
%% Bin :
%% SendBinary :
%% [IsManagement : false]
%%
%% ok | {error,Reason}
%%
connectterm(Socket,Bin,SendBinary) ->
	connectterminal(Socket,Bin,SendBinary,false).

%%
%% If the server cannot send message to the terminal, the message will be discard.
%% It is because the terminal should do the request again.
%%
%% Socket :
%% Bin :
%% SendBinary :
%% IsManagement :
%%
%% ok | {error,Reason}
%%
connectterminal(Socket,Bin,SendBinary,IsManagement) ->
	if
		IsManagement == true ->
			TermString = "man-term";
		IsManagement == false ->
			TermString = "term"
	end,
	if
		SendBinary == true ->
			case is_list(Bin) of
				true ->
					BinResp = list_to_binary(Bin);
				false ->
					case is_binary(Bin) of
						true ->
							BinResp = Bin;
						false ->
							logerror("Unknown server data : ~p~n",[Bin]),
							BinResp = ?UNKNWON_SERVER_DATA
					end
			end;
		SendBinary == false ->
			case is_binary(Bin) of
				true ->
					BinResp = binary_to_list(Bin);
				false ->
					case is_list(Bin) of
						true ->
							BinResp = Bin;
						false ->
							logerror("Unknown server data : ~p~n",[Bin]),
							BinResp = ?UNKNWON_SERVER_DATA
					end
			end
	end,
	try gen_tcp:send(Socket,BinResp) of
		ok ->
			ok;
		{error,Reason} ->
			logerror("Send data to " + TermString + " (~p) fails : ~p~n",[Socket,Reason]),
			{error,Reason}
	catch
        _:Why ->
			logerror("Send data to " + TermString + " (~p) exception : ~p~n",[Socket,Why]),
			{error,Why}
	end.

closetcpsocket(Socket,Who) ->
	try gen_tcp:close(Socket)
	catch
		_:Why ->
			logerror("Close " + Who + " socket (~p) exception : ~p~n", [Socket,Why]),
			logerror("Ignore exception~n")
	end.

%%
%% terminstancetable will include Socket and TimeStamp so that we can know which Socket is a dead one.
%% For exmple, no intercative from a Socket for more than 120s.
%%
inserttermsocket(Socket) ->
	TimeStamp = calendar:now_to_local_time(erlang:now()),
	try inet:peername(Socket) of
		{ok,{Address,Port}} ->
			ets:insert(terminstancetable, {Socket,Address,Port,TimeStamp});
		{error,Reason} ->
			logerror("Check term socket fails : ~p",Reason),
			ets:insert(terminstancetable, {Socket,"0.0.0.0","0",TimeStamp})
	catch
		_:Why ->
			logerror("Check term socket exception : ~p",Why),
			ets:insert(terminstancetable, {Socket,"0.0.0.0","0",TimeStamp})
	end.

deletetermsocket(Socket) ->
	ets:delete(terminstancetable, Socket).

%%
%% maninstancetable will include Socket and TimeStamp so that we can know which Socket is a dead one.
%% For exmple, no intercative from a Socket for more than 120s.
%%
insertmansocket(Socket) ->
	TimeStamp = calendar:now_to_local_time(erlang:now()),
	try inet:peername(Socket) of
		{ok,{Address,Port}} ->
			ets:insert(maninstancetable, {Socket,Address,Port,TimeStamp});
		{error,Reason} ->
			logerror("Check man term socket fails : ~p",Reason),
			ets:insert(maninstancetable, {Socket,"0.0.0.0","0",TimeStamp})
	catch
		_:Why ->
			logerror("Check man term socket exception : ~p",Why),
			ets:insert(maninstancetable, {Socket,"0.0.0.0","0",TimeStamp})
	end.

deletemansocket(Socket) ->
	ets:delete(maninstancetable, Socket).

%% Each time when the server startup,
%% the saved old requests should first be processed.
processsavedrequests() ->
	ok.

loginfo(Format) ->
	logserver(Format,?MSG_LEVEL_INFO).

loginfo(Format,Data) ->
	logserver(Format,Data,?MSG_LEVEL_INFO).

%%logwarning(Format) ->
%%	logserver(Format,?MSG_LEVEL_WARNING).

logwarning(Format,Data) ->
	logserver(Format,Data,?MSG_LEVEL_WARNING).

logerror(Format) ->
	logserver(Format,?MSG_LEVEL_ERROR).

logerror(Format,Data) ->
	logserver(Format,Data,?MSG_LEVEL_ERROR).

logserver(Format,Data,Level) ->
	case is_list(Data) of
		true ->
			try io_lib:format(Format, Data) of
				FormatData ->
					try lists:flatten(FormatData) of
						List ->
							logserver(List,Level)
					catch
						_:_ ->
							logserver(FormatData,Level)
					end
			catch
				_:_ ->
					logserver("Cannot format data~n",?MSG_LEVEL_ERROR),
					logserver(Format,Level),
					try lists:flatten(Data) of
						List ->
							logserver(List,Level)
					catch
						_:_ ->
							loglist(Data,Level)
					end
			end;
		false ->
			try io_lib:format(Format, [Data]) of
				FormatData ->
					try lists:flatten(FormatData) of
						String ->
							logserver(String,Level)
					catch
						_:_ ->
							logserver(FormatData,Level)
					end
			catch
				_:_ ->
					logserver("Cannot format data~n",?MSG_LEVEL_ERROR),
					logserver(Format,Level),
					logserver(Data,Level)
			end
	end.

loglist(List,Level) ->
	case List of
		[] ->
			ok;
		_ ->
			[First|Others] = List,
			try logserver(First,Level) of
				_ ->
					ok
			catch
				_:_ ->
					logserver("Cannot output data~n",?MSG_LEVEL_ERROR)
			end,
			loglist(Others,level)
	end.

logserver(FormatData,Level) ->
	try dologserver(FormatData,Level) of
		_ ->
			ok
	catch
		_:_ ->
			dologserver("Cannot output data~n",?MSG_LEVEL_ERROR)
	end.
			
dologserver(FormatData,Level) ->
	[{logserverlevel,LogLevel}] = ets:lookup(serverstatetable, logserverlevel),
	if
		LogLevel =< Level ->
			TimeStamp = calendar:now_to_local_time(erlang:now()),
			ets:insert(serverlogtable, {TimeStamp,Level,FormatData}),
			[{displaylog,DisplayLog}] = ets:lookup(serverstatetable, displaylog),
			if
				DisplayLog == true ->
					case Level of
						?MSG_LEVEL_INFO ->
							io:format("~p : ~p~n",[TimeStamp,FormatData]),
							case is_binary(FormatData) of
								true ->
									try binary_to_list(FormatData) of
										FormatStr ->
											io:format("~p (string) : ~p~n",[TimeStamp,FormatStr])
									catch
										_:_ ->
											ok
									end;
								_ ->
									ok
							end;								
						?MSG_LEVEL_WARNING ->
							io:format("W : ~p : ~p~n",[TimeStamp,FormatData]),
							case is_binary(FormatData) of
								true ->
									try binary_to_list(FormatData) of
										FormatStr ->
											io:format("~p (string) : ~p~n",[TimeStamp,FormatStr])
									catch
										_:_ ->
											ok
									end;
								_ ->
									ok
							end;								
						?MSG_LEVEL_ERROR ->
							io:format("E : ~p : ~p~n",[TimeStamp,FormatData]),
							case is_binary(FormatData) of
								true ->
									try binary_to_list(FormatData) of
										FormatStr ->
											io:format("~p (string) : ~p~n",[TimeStamp,FormatStr])
									catch
										_:_ ->
											ok
									end;
								_ ->
									ok
							end;								
						_ ->
							io:format("? : ~p : ~p~n",[TimeStamp,FormatData]),
							case is_binary(FormatData) of
								true ->
									try binary_to_list(FormatData) of
										FormatStr ->
											io:format("~p (string) : ~p~n",[TimeStamp,FormatStr])
									catch
										_:_ ->
											ok
									end;
								_ ->
									ok
							end								
					end;
				DisplayLog == false ->
					ok
			end;
		LogLevel > Level ->
			ok
	end.
