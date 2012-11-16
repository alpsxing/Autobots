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
-export([start/0,start/1,start/2,start/8,stop/0]).

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
	start(HttpServer,?HTTP_PROCESSES_COUNT,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,DisplayLog,LogLevel).

start() ->
	start(false).
start(DisplayLog) ->
	start(DisplayLog,?MSG_LEVEL_ERROR).
start(DisplayLog,LogLevel) ->
	start(?HTTP_SERVER_NOPORT,?HTTP_PROCESSES_COUNT,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,DisplayLog,LogLevel).
start(HttpServer,HttpInstCount,TcpServer,TcpPort,TcpServer2,TcpPort2,DisplayLog,LogLevel) ->
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
			spawn(fun() -> connectmanagement(ListenMan,0) end);
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
		_ ->
			loginfo("Http dispatcher started~n")
	catch
		_:WhyDispatcher ->
			logerror("Http dispacteher exception : ~p and exits~n",[WhyDispatcher]),
			exit(WhyDispatcher)
	end.
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

starthttpdispatcher(HttpServer) ->
	Pid = spawn(fun() -> httpdispatcherprocinst(HttpServer,0) end),
	TimeStamp = calendar:now_to_local_time(erlang:now()),
	ets:insert(serverstatetable, {httpdispatcher,Pid,TimeStamp}),
	loginfo("Http dispatcher process PID : ~p~n",Pid).

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
			TimeStamp1 = calendar:now_to_local_time(erlang:now()),
			ets:insert(serverstatetable, {httpdispatcher,self(),TimeStamp1});
		NormHttpProcCount >= 1 ->
			if
				NormHttpProcCount < ?HTTP_PROCESSES_MIN_COUNT ->
					logwarning("The count of active http connections are =< ~p~n",[?HTTP_PROCESSES_MIN_COUNT]);
				NormHttpProcCount >= ?HTTP_PROCESSES_MIN_COUNT ->
					ok
			end,
			HttpProcCount = ets:select_count(httpprocesstable, [{{'$1'},[],[true]}]),
			if
				HttpProcCount < 1 ->
					loginfo("No idle http connection and http dispatcher waits.~n"),
					timer:sleep(1);
				HttpProcCount >= 1 ->
					if
						HttpProcCount < ?HTTP_PROCESSES_MIN_COUNT ->
							logwarning("The count of idle http connections are =< ~p~n",[?HTTP_PROCESSES_MIN_COUNT]);
						HttpProcCount >= ?HTTP_PROCESSES_MIN_COUNT ->
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
							%% It is only for debug mode
							%% !!!
							%%loginfo("Current http process id : ~p~n",Pid),
							ets:delete(httpprocesstable, Pid),
							HDPid = self(),
							spawn(fun() -> httpdispatcherprocess(HttpServer,HDPid,Pid,Msges) end)
					end
			end,
			httpdispatcherprocinst(HttpServer,NewIndex)
	end.

httpdispatcherprocess(HttpServer,HDPid,Pid,Msges) ->
	case Msges of
		[] ->
			ets:insert(httpprocesstable, {Pid});
		_ ->
			[First|Others] = Msges,
			Pid!{HDPid,First},
			httpdispatcherprocess(HttpServer,HDPid,Pid,Others)
	end.
			
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
	ProcPid = spawn(fun() -> singlehttpprocess(HttpServer) end),
	ets:insert(httpprocesstable, {ProcPid}),
	ets:insert(normalhttpprocesstable, {ProcPid}).

singlehttpprocess(HttpServer) ->
	receive
		{HDPid,Msg} ->
			[{httpdispatcher,Pid,_}] = ets:lookup(serverstatetable, httpdispatcher),
			case HDPid of
				Pid ->
					{TimeStamp,Address,Port,HttpBin} = Msg,
					case connecthttpserver(HttpServer,TimeStamp,Address,Port,HttpBin) of
						ok ->
							singlehttpprocess(HttpServer);
						{error,Reason} ->
							logerror("Http process ~p error : ~p~n",[self(),Reason]),
							ets:delete(httpprocesstable, self()),
							ets:delete(normalhttpprocesstable, self())
					end;
				_ ->
					loginfo("Http process ~p received unknown http message souce Pid : ~p~n", [self(),HDPid]),
					singlehttpprocess(HttpServer)
			end;
		stop ->
			loginfo("Http process ~p is required to stop~n", self()),
			ets:delete(normalhttpprocesstable, self())
	end.

%%
%%post(URL, ContentType, Body) -> request(post, {URL, [], ContentType, Body}).
%%get(URL)                     -> request(get,  {URL, []}).
%%head(URL)                    -> request(head, {URL, []}).
%%
connecthttpserver(HttpServer,TimeStamp,Address,Port,HttpBin) ->
	%% !!!
	%% Please check the parameters of the method httpc:request(...)
	%% !!!
	TimeStamp,
	Address,
	Port,
	ContentType = "text/json",
	Options = [{body_format,binary}],
	try httpc:request(post,{HttpServer,[],ContentType,HttpBin},[],Options) of
		{ok,_} ->
			%%TimeStamp = calendar:now_to_local_time(erlang:now()),
			%%ets:insert(serverstatetable,{lasthttptimestamp,TimeStamp}),
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
	ets:insert(serverstatetable,{masterjitcontfail,0}),
	ets:insert(serverstatetable,{masterjittotalfail,0}),
	ets:insert(serverstatetable,{jitservercontfail,0}),
	ets:insert(serverstatetable,{jitservertotalfail,0}),
	ets:insert(serverstatetable,{logserverlevel,LogLevel}),
	ets:insert(serverstatetable,{orilogserverlevel,LogLevel}),
	ets:insert(serverstatetable,{httpprocessmin,?HTTP_PROCESSES_MIN_COUNT}),
	ets:insert(serverstatetable,{httpprocessmax,?HTTP_PROCESSES_MAX_COUNT}),
	TimeStamp = calendar:now_to_local_time(erlang:now()),
	ets:insert(serverstatetable,{httpdispatcher,self(),TimeStamp}),
	%% It will bring too much burden for the system
	%%ets:insert(serverstatetable,{lastjittimestamp,TimeStamp}),
	%% It will bring too much burden for the system
	%%ets:insert(serverstatetable,{lasthttptimestamp,TimeStamp}),
	ets:insert(serverstatetable,{mantotalfail,0}),
	%% It will bring too much burden for the system
	%%ets:insert(serverstatetable,{lastmantimestamp,TimeStamp}),
	ets:insert(serverstatetable,{termtotalfail,0}),
	%% It will bring too much burden for the system
	%%ets:insert(serverstatetable,{lasttermtimestamp,TimeStamp}),
	ets:insert(serverstatetable,{acceptmancontfail,0}),
	ets:insert(serverstatetable,{acceptmantotalfail,0}),
	%% It will bring too much burden for the system
	%%ets:insert(serverstatetable,{lastacceptmantimestamp,TimeStamp}),
	ets:insert(serverstatetable,{accepttermcontfail,0}),
	ets:insert(serverstatetable,{accepttermtotalfail,0}),
	%% It will bring too much burden for the system
	%%ets:insert(serverstatetable,{lastaccepttermtimestamp,TimeStamp}),
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
		Count == ?ACCEPT_MT_ERROR_CONT_MAX ->
			logerror("Stop accepting man-term because of continous failures reaches the limit : ~p~n",[?ACCEPT_MT_ERROR_CONT_MAX]);
		Count > ?ACCEPT_MT_ERROR_CONT_MAX + 1 ->
			ok;
		Count < ?ACCEPT_MT_ERROR_CONT_MAX ->
		    try	gen_tcp:accept(Listen) of
				{ok,Socket} ->
					spawn(fun() -> connectmanagement(Listen,0) end),
					%%TimeStamp = calendar:now_to_local_time(erlang:now()),
					%%ets:insert(serverstatetable, {lastacceptmantimestamp,TimeStamp}),
					ets:insert(serverstatetable, {acceptmancontfail,0}),
					insertmansocket(Socket),
		           	loopmanagement(Socket);
				{error,Reason} ->
					[{acceptmantotalfail,TotalCount}] = ets:lookup(serverstatetable, acceptmantotalfail),
					ets:insert(serverstatetable, {acceptmancontfail,Count+1}),
					ets:insert(serverstatetable, {acceptmantotalfail,TotalCount+1}),
					logerror("Accepting man-term failures (continous ~p/total ~p) : ~p~n",[Count+1,TotalCount+1,Reason]),
		           	spawn(fun() -> connectmanagement(Listen,Count+1) end)
			catch
				_:Why ->
					[{acceptmantotalfail,TotalCount}] = ets:lookup(serverstatetable, acceptmantotalfail),
					ets:insert(serverstatetable, {acceptmancontfail,Count+1}),
					ets:insert(serverstatetable, {acceptmantotalfail,TotalCount+1}),
					logerror("Accepting man-term exceptions (continous ~p/total ~p) : ~p~n",[Count+1,TotalCount+1,Why]),
		           	spawn(fun() -> connectmanagement(Listen,Count+1) end)
			end
	end.

loopmanagement(Socket) ->
	{_,{Address,Port}}=getsafepeername(Socket),
	receive
		{tcp,Socket,Bin} ->
			BinResp = processmanagementdata(Bin),
			case connectmanterm(Socket,BinResp) of
				ok ->
					inet:setopts(Socket,[{active,once}]),
					%%TimeStamp = calendar:now_to_local_time(erlang:now()),
					%%ets:insert(serverstatetable,{lastmantimestamp,TimeStamp}),
					loopmanagement(Socket);
				{error,Reason} ->
					logerror("Close and delete man-term socket (~p:~p) because of sending response data to man-term error : ~p~n", [Address,Port,Reason]),
					[{mantotalfail,TotalCount}] = ets:lookup(serverstatetable, mantotalfail),
					ets:insert(serverstatetable,{mantotalfail,TotalCount+1}),
					deletemansocket(Socket),
					closetcpsocket(Socket,"man-term")
			end;
		{tcp_closed,Socket} ->
			loginfo("Delete man-term socket (~p:~p) because man-term has closed it~n", [Address,Port]),
			deletemansocket(Socket);
		{tcp_error,Socket} ->
			logerror("Close and delete man-term socket (~p:~p) because of tcp_error~n", [Address,Port]),
			[{mantotalfail,TotalCount}] = ets:lookup(serverstatetable, mantotalfail),
			ets:insert(serverstatetable,{mantotalfail,TotalCount+1}),
			deletemansocket(Socket),
			closetcpsocket(Socket,"man-term");
		{tcp_error,Socket,Reason} ->
			logerror("Close and delete man-term socket (~p:~p) because of tcp_error : ~p~n", [Address,Port,Reason]),
			[{mantotalfail,TotalCount}] = ets:lookup(serverstatetable, mantotalfail),
			ets:insert(serverstatetable,{mantotalfail,TotalCount+1}),
			deletemansocket(Socket),
			closetcpsocket(Socket,"man-term");
		Msg ->
			logerror("Colose man-term socket (~p:~p) because of unknown server state : ~p~n", [Address,Port,Msg]),
			[{mantotalfail,TotalCount}] = ets:lookup(serverstatetable, mantotalfail),
			ets:insert(serverstatetable,{mantotalfail,TotalCount+1}),
			deletemansocket(Socket),
			closetcpsocket(Socket,"man-term")
 	after ?MT_TCP_RECEIVE_TIMEOUT ->
		logerror("Close and delete man-term (~p:~p) socket (~p) because no data is received after ~p ms~n", [Address,Port,Socket,?MT_TCP_RECEIVE_TIMEOUT]),
		[{mantotalfail,TotalCount}] = ets:lookup(serverstatetable, mantotalfail),
		ets:insert(serverstatetable,{mantotalfail,TotalCount+1}),
		deletemansocket(Socket),
		closetcpsocket(Socket,"man-term")
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
			string:concat(?MT_UNKNOWN_SERVER_ERROR,Why)
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
						?MT_CLR_BOTH_JIT_CONT_FAIL ->
							ets:insert(serverstatetable, {jitservercontfail,0}),
							?MT_CLR_BOTH_JIT_CONT_FAIL_OK;
						?MT_CLR_BOTH_JIT_TOTAL_FAIL ->
							ets:insert(serverstatetable, {jitservertotalfail,0}),
							?MT_CLR_BOTH_JIT_TOTAL_FAIL_OK;
						?MT_CLR_MASTER_JIT_CONT_FAIL ->
							ets:insert(serverstatetable, {masterjitcontfail,0}),
							?MT_CLR_MASTER_JIT_CONT_FAIL_OK;
						?MT_CLR_MASTER_JIT_TOTAL_FAIL ->
							ets:insert(serverstatetable, {masterjittotalfail,0}),
							?MT_CLR_MASTER_JIT_TOTAL_FAIL_OK;
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
							Value = ets:select_count(msg2httptable, [{{'$1','$2','$3','$4'},[],[true]}]),
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
							Value = ets:select_count(msg2jittable, [{{'$1','$2','$3','$4'},[],[true]}]),
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
							Value = ets:select_count(msg2terminaltable, [{{'$1','$2','$3','$4'},[],[true]}]),
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
						?MT_QRY_BOTH_JIT_CONT_FAIL ->
							[{jitservercontfail,Value}] = ets:lookup(serverstatetable, jitservercontfail),	
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_BOTH_JIT_CONT_FAIL_OK, Str);
						?MT_QRY_BOTH_JIT_TOTAL_FAIL ->
							[{jitservertotalfail,Value}] = ets:lookup(serverstatetable, jitservertotalfail),	
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_BOTH_JIT_TOTAL_FAIL_OK, Str);
						?MT_QRY_MASTER_JIT_CONT_FAIL ->
							[{masterjitcontfail,Value}] = ets:lookup(serverstatetable, masterjitcontfail),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_MASTER_JIT_CONT_FAIL_OK, Str);
						?MT_QRY_MASTER_JIT_TOTAL_FAIL ->
							[{masterjittotalfail,Value}] = ets:lookup(serverstatetable, masterjittotalfail),
							Str=integer_to_list(Value),
							string:concat(?MT_QRY_MASTER_JIT_TOTAL_FAIL_OK, Str);
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
									string:concat(?MT_UNKNOWN_MT_DATA, Body)
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
									string:concat(?MT_UNKNOWN_MT_DATA, Body)
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
									string:concat(?MT_UNKNOWN_MT_DATA, Body)
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
							?MT_SET_HTTP_PROC_WARN_COUNT_ERR;
						?MT_QRY_HTTP_DISPATCHER_TIME ->
							?MT_QRY_HTTP_DISPATCHER_TIME_ERR
						%%?MT_QRY_LAST_VISIT_JIT_OK_TIME ->
						%%	?MT_QRY_LAST_VISIT_JIT_OK_TIME_ERR
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
			S1 = string:concat(Address, ","),
			case is_integer(Port) of
				true ->
					S2 = string:concat(S1, integer_to_list(Port));
				false ->
					S2 = string:concat(S1, Port)
			end,
			S3 = string:concat(S2, ","),
			S4 = string:concat(S3, composetimestamp(TimeStamp)),
			case Others of
				[] ->
					S4;
				_ ->
					S5 = string:concat(S4, ";"),
					string:concat(S5, getallmanterm(Others))
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
	[{masterjitcontfail,MasterContFai}] = ets:lookup(serverstatetable,masterjitcontfail),
	S30 = string:concat(S2, ";MasterContFail:"),
	S3 = string:concat(S30, integer_to_list(MasterContFai)),
	[{jitservercontfail,JitContFail}] = ets:lookup(serverstatetable,jitservercontfail),
	S40 = string:concat(S3, ";JitContFail:"),
	S4 = string:concat(S40, integer_to_list(JitContFail)),
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
	Msg2JitCount = ets:select_count(msg2jittable, [{{'$1','$2','$3','$4'},[],[true]}]),
	S110 = string:concat(S10, ";Msg2JitCount:"),
	S11 = string:concat(S110, integer_to_list(Msg2JitCount)),
	Msg2HttpCount = ets:select_count(msg2httptable, [{{'$1','$2','$3','$4'},[],[true]}]),
	S120 = string:concat(S11, ";Msg2HttpCount:"),
	S12 = string:concat(S120, integer_to_list(Msg2HttpCount)),
	LogCount = ets:select_count(serverlogtable, [{{'$1','$2','$3'},[],[true]}]),
	S130 = string:concat(S12, ";LogCount:"),
	S13 = string:concat(S130, integer_to_list(LogCount)),
	Msg2TermCount = ets:select_count(msg2terminaltable, [{{'$1','$2','$3','$4'},[],[true]}]),
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
	S190 = string:concat(S18, ";HttpDispatcher:"),
	S19 = string:concat(S190, composetimestamp(TimeStamp)),
	HttpAvailableCount = ets:select_count(normalhttpprocesstable, [{{'$1'},[],[true]}]),
	S200 = string:concat(S19, ";HttpAvailableCount:"),
	S20 = string:concat(S200, integer_to_list(HttpAvailableCount)),
	[{httpprocessmin,HttpMin}] = ets:lookup(serverstatetable,httpprocessmin),
	S210 = string:concat(S20, ";HttpMin:"),
	S21 = string:concat(S210, integer_to_list(HttpMin)),
	[{httpprocessmax,HttpMax}] = ets:lookup(serverstatetable,httpprocessmax),
	S220 = string:concat(S21, ";HttpMax:"),
	S22 = string:concat(S220, integer_to_list(HttpMax)),
	%%[{lastjittimestamp,JitTimeStamp}]= ets:lookup(serverstatetable,lastjittimestamp),
	%%S230 = string:concat(S22, ";LastJitTS:"),
	%%S23 = string:concat(S230, composetimestamp(JitTimeStamp)),
	[{masterjittotalfail,MasterTotalFail}] = ets:lookup(serverstatetable,masterjittotalfail),
	S240 = string:concat(S22, ";MasterTotalFail:"),
	S24 = string:concat(S240, integer_to_list(MasterTotalFail)),
	[{jitservertotalfail,JitTotalFail}] = ets:lookup(serverstatetable,jitservertotalfail),
	S250 = string:concat(S24, ";JitTotalFail:"),
	S25 = string:concat(S250, integer_to_list(JitTotalFail)),
	%%[{lasthttptimestamp,HttpTimeStamp}]= ets:lookup(serverstatetable,lasthttptimestamp),
	%%S260 = string:concat(S25, ";LastHttpTS:"),
	%%S26 = string:concat(S260, composetimestamp(HttpTimeStamp)),
	[{mantotalfail,ManTotalFail}] = ets:lookup(serverstatetable,mantotalfail),
	S270 = string:concat(S25, ";ManTotalFail:"),
	S27 = string:concat(S270, integer_to_list(ManTotalFail)),
	[{termtotalfail,TermTotalFail}] = ets:lookup(serverstatetable,termtotalfail),
	S280 = string:concat(S27, ";TermTotalFail:"),
	S28 = string:concat(S280, integer_to_list(TermTotalFail)),
	%%[{lastmantimestamp,ManTimeStamp}]= ets:lookup(serverstatetable,lastmantimestamp),
	%%S290 = string:concat(S28, ";LastManTS:"),
	%%S29 = string:concat(S290, composetimestamp(ManTimeStamp)),
	%%[{lasttermtimestamp,TermTimeStamp}]= ets:lookup(serverstatetable,lasttermtimestamp),
	%%S300 = string:concat(S29, ";LastTermTS:"),
	%%S30 = string:concat(S300,composetimestamp(TermTimeStamp)), %% why this compsetimestamp will crash?
	%%[{lastacceptmantimestamp,AccManTimeStamp}]= ets:lookup(serverstatetable,lastacceptmantimestamp),
	%%S310 = string:concat(S28, ";LastAccManTS:"),
	%%S31 = string:concat(S310, composetimestamp(AccManTimeStamp)),
	%%[{lastaccepttermtimestamp,AccTermTimeStamp}]= ets:lookup(serverstatetable,lastaccepttermtimestamp),
	%%S320 = string:concat(S31, ";LastAccTermTS:"),
	%%S32 = string:concat(S320, composetimestamp(AccTermTimeStamp)),
	{ok,S28}.

composetimestamp(TimeStamp) ->
	{{Year,Month,Day},{Hour,Minute,Second}} = TimeStamp,
	S1 = lists:flatten(io_lib:format('~4..0b-~2..0b-~2..0b', [Year, Month, Day])),
	S2 = string:concat(S1, " "),
	string:concat(S2, lists:flatten(io_lib:format('~2..0b:~2..0b:~2..0b', [Hour, Minute, Second]))).

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
		Count > ?ACCEPT_TERM_ERROR_CONT_MAX ->
			ok;
		Count == ?ACCEPT_TERM_ERROR_CONT_MAX ->
			logerror("Stop accepting term because of continous failures reaches the limit : ~p~n",[?ACCEPT_TERM_ERROR_CONT_MAX]);
		Count < ?ACCEPT_TERM_ERROR_CONT_MAX ->
		    try	gen_tcp:accept(Listen) of
				{ok,Socket} ->
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,1) end),
					%%TimeStamp = calendar:now_to_local_time(erlang:now()),
					%%ets:insert(serverstatetable, {lastaccepttermtimestamp,TimeStamp}),
					ets:insert(serverstatetable, {accepttermcontfail,0}),
					inserttermsocket(Socket),
		           	loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2);
				{error,Reason} ->
					[{accepttermtotalfail,TotalCount}] = ets:lookup(serverstatetable, accepttermtotalfail),
					ets:insert(serverstatetable, {accepttermcontfail,Count+1}),
					ets:insert(serverstatetable, {accepttermtotalfail,TotalCount+1}),
					logerror("Accepting term fails (cont ~p/total ~p) : ~p~n",[Count+1,TotalCount+1,Reason]),
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count+1) end)
			catch
				_:Why ->
					[{accepttermtotalfail,TotalCount}] = ets:lookup(serverstatetable, accepttermtotalfail),
					ets:insert(serverstatetable, {accepttermcontfail,Count+1}),
					ets:insert(serverstatetable, {accepttermtotalfail,TotalCount+1}),
					logerror("Accepting term exceptions (cont ~p/total ~p) : ~p~n",[Count+1,TotalCount+1,Why]),
		           	spawn(fun() -> connect(Listen,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Count+1) end)
			end
	end.

%%
%% If server hasn't received an data from the terminal after ?TCP_RECEIVE_TIMEOUT ms, the socket of the terminal will be closed.
%%
loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2) ->
	{_,{Address,Port}}=getsafepeername(Socket,false),
	receive
		{tcp,Socket,Bin} ->
			%% It is safe for the same terminal because each terminal is not allowed to report very frequenctly.
			%% The time interval is 60m which is needed to be checked with the planner.
			TimeStamp = calendar:now_to_local_time(erlang:now()),
			case httpservermessage(Bin) of
				true ->
					HttpMsgCount=ets:select_count(msg2httptable, [{{'$1','$2','$3','$4'},[],[true]}]),
					case HttpMsgCount of
						?TO_HTTP_WARN_MESSAGE_COUNT ->
							logwarning("The count of msg2http reaches the warning number : ~p~n",[?TO_HTTP_WARN_MESSAGE_COUNT]);
						?TO_HTTP_MAX_MESSAGE_COUNT -> 
							logerror("New msg2http will be discarded because the count of msg2http reaches the max number : ~p~n",[?TO_HTTP_MAX_MESSAGE_COUNT]);
						_ ->
							ok
					end,
					if
						HttpMsgCount >= ?TO_HTTP_MAX_MESSAGE_COUNT ->
							logerror("Delete and close the current term socket (~p:~p) because the count of msg2http reaches the max number : ~p~n",[Address,Port,?TO_HTTP_MAX_MESSAGE_COUNT]),
							deletetermsocket(Socket),
							closetcpsocket(Socket,"term");
						HttpMsgCount < ?TO_HTTP_MAX_MESSAGE_COUNT ->
				            HttpBin = dataprocessor:tcp2http(Bin),
							NormalHttpProcCount=ets:select_count(normalhttpprocesstable, [{{'$1'},[],[true]}]),
							if
								NormalHttpProcCount < 1 ->
									logerror("Close and delete term socket (~p:~p) because of no active http connection.~n", [Address,Port]),
									deletetermsocket(Socket),
									closetcpsocket(Socket,"term");
								NormalHttpProcCount >= 1 ->
									if
										NormalHttpProcCount < ?HTTP_PROCESSES_MIN_COUNT ->
											logwarning("The count of active http connections (~p) < the warning number : ~p~n",[NormalHttpProcCount,?HTTP_PROCESSES_MIN_COUNT]);
										NormalHttpProcCount >= ?HTTP_PROCESSES_MIN_COUNT ->
											ok
									end,
									ets:insert(msg2httptable, {TimeStamp,Address,Port,HttpBin}),
									doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin)
							end
					end;
				false ->
					NormalHttpProcCount=ets:select_count(normalhttpprocesstable, [{{'$1'},[],[true]}]),
					if
						NormalHttpProcCount < 1 ->
							logerror("Close and delete term socket (~p:~p) because of no active http connection.~n", [Address,Port]),
							deletetermsocket(Socket),
							closetcpsocket(Socket,"term");
						NormalHttpProcCount >= 1 ->
							case NormalHttpProcCount of
								?HTTP_PROCESSES_MIN_COUNT ->
									logwarning("The count of active http connections is decreased to the warning number : ~p~n",[?HTTP_PROCESSES_MIN_COUNT]);
								_ ->
									ok
							end,
							doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin)
					end
			end;
		{tcp_closed,Socket} ->
			loginfo("Delete term socket (~p:~p) because term has closed it~n", [Address,Port]),
			deletetermsocket(Socket);
		{tcp_error,Socket} ->
			logerror("Close and delete term socket (~p:~p) because of tcp_error~n", [Address,Port]),
			[{termtotalfail,TotalCount}] = ets:lookup(serverstatetable, termtotalfail),
			ets:insert(serverstatetable,{termtotalfail,TotalCount+1}),
			deletetermsocket(Socket),
			closetcpsocket(Socket,"term");
		{tcp_error,Socket,Reason} ->
			logerror("Close and delete term socket (~p:~p) because of tcp_error : ~n", [Address,Port,Reason]),
			[{termtotalfail,TotalCount}] = ets:lookup(serverstatetable, termtotalfail),
			ets:insert(serverstatetable,{termtotalfail,TotalCount+1}),
			deletetermsocket(Socket),
			closetcpsocket(Socket,"term");
		Msg ->
			logerror("Colose term socket (~p:~p) because of unknown server state : ~p~n", [Address,Port,Msg]),
			[{termtotalfail,TotalCount}] = ets:lookup(serverstatetable, termtotalfail),
			ets:insert(serverstatetable,{termtotalfail,TotalCount+1}),
			deletetermsocket(Socket),
			closetcpsocket(Socket,"term")
 	after ?TERM_TCP_RECEIVE_TIMEOUT ->
		logerror("Close and delete term socket (~p:~p) because no data is received after ~p ms~n", [Address,Port,?TERM_TCP_RECEIVE_TIMEOUT]),
		[{termtotalfail,TotalCount}] = ets:lookup(serverstatetable, termtotalfail),
		ets:insert(serverstatetable,{termtotalfail,TotalCount+1}),
		deletemansocket(Socket),
		closetcpsocket(Socket,"term")
    end.
	
%%
%% Check this message from the terminal should be sent to the http server or not
%%
httpservermessage(Bin) ->
	Bin,
	true.

doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin) ->
	{_,{Address,Port}}=getsafepeername(Socket),
	[{jitservercontfail,JitContFail}] = ets:lookup(serverstatetable, jitservercontfail),
	if
		JitContFail == ?CONNECT_JIT_CONT_FAIL_COUNT ->
			logerror("New msg2jit will be stored becasue the count of continous failures in both jit servers reaches the limit : ~p~n",[?CONNECT_JIT_CONT_FAIL_COUNT]),
			savemsg2tcp(TimeStamp,Address,Port,Bin),
			logerror("Close and delete term socket (~p:~p)~n", [Address,Port]),
			deletetermsocket(Socket),
			closetcpsocket(Socket,"term");
		JitContFail > ?CONNECT_JIT_CONT_FAIL_COUNT ->
			savemsg2tcp(TimeStamp,Address,Port,Bin),			
			logerror("Close and delete term socket (~p:~p)~n", [Address,Port]),
			deletetermsocket(Socket),
			closetcpsocket(Socket,"term");
		JitContFail < ?CONNECT_JIT_CONT_FAIL_COUNT ->
			[{usemasterjit,UseMaster}] = ets:lookup(serverstatetable, usemasterjit),
			case connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster,Socket,TimeStamp,Bin) of
				{ok, BinResp} ->
					ets:insert(serverstatetable, {jitservercontfail,0}),
					%%JitTimeStamp = calendar:now_to_local_time(erlang:now()),
					%%ets:insert(serverstatetable,{lastjittimestamp,JitTimeStamp}),
					case connectterm(Socket,BinResp) of
						ok ->
				 	        inet:setopts(Socket,[{active,once}]),
				            loop(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2);
							%%TermTimeStamp = calendar:now_to_local_time(erlang:now()),
							%%ets:insert(serverstatetable,{lasttermtimestamp,TermTimeStamp});
						{error,Reason} ->
							logerror("Close and delete term socket (~p:~p) because of both jit servers error : ~p~n",[Address,Port,Reason]),
							%% !!!
							%% Need to consider whether it is necessary to store the response from jit server to the terminal
							%% !!!
							%%logerror("Close and delete term socket (~p:~p) and msg2terminal will be store because of term socket error : ~p~n",[Address,Port,Reason]),
							%%ets:insert(msg2terminaltable, {TimeStamp,Address,Port,BinResp}),
							[{termtotalfail,TotalCount}] = ets:lookup(serverstatetable, termtotalfail),
							ets:insert(serverstatetable,{termtotalfail,TotalCount+1}),
							deletetermsocket(Socket),
							closetcpsocket(Socket,"term")
					end;
				{error,Reason} ->
					logerror("Close and delete term socket (~p:~p) because of both jit servers error : ~p~n",[Address,Port,Reason]),
					%%[{termtotalfail,TotalCount}] = ets:lookup(serverstatetable, termtotalfail),
					%%ets:insert(serverstatetable,{termtotalfail,TotalCount+1}),
					deletetermsocket(Socket),
					closetcpsocket(Socket,"term")
			end
	end.

savemsg2tcp(TimeStamp,Address,Port,Bin) ->
	JitMsgCount=ets:select_count(msg2jittable, [{{'$1','$2','$3','$4'},[],[true]}]),
	if
		JitMsgCount > ?TO_JIT_MAX_MESSAGE_COUNT ->
			ok;
		JitMsgCount == ?TO_JIT_MAX_MESSAGE_COUNT ->
			logerror("New msg2jit will be discarded because the count of msg2jit reaches the max number : ~p~n",[?TO_JIT_MAX_MESSAGE_COUNT]);
		JitMsgCount < ?TO_JIT_MAX_MESSAGE_COUNT ->
			ets:insert(msg2jittable, {TimeStamp,Address,Port,Bin})
	end.

%%
%% The master tcp server will be first tried and if it fails, the slave tcpserver will be used.
%% If return error, it means both master and slave tcp servers are unavailable.
%% If any one of the two servers is ok, will return {ok,BinResp}
%%
connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,UseMaster,Socket,TimeStamp,Bin) ->
	if
		UseMaster == true ->
			[{masterjitcontfail,MJitContFail}] = ets:lookup(serverstatetable, masterjitcontfail),
			if
				MJitContFail == ?CONNECT_JIT_CONT_FAIL_COUNT ->
					logwarning("Slave will be used because the count of continous failures in master reaches the limit :~p~n",[?CONNECT_JIT_CONT_FAIL_COUNT]),
					connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,false,Socket,TimeStamp,Bin);
				MJitContFail > ?CONNECT_JIT_CONT_FAIL_COUNT ->
					connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,false,Socket,TimeStamp,Bin);
				MJitContFail < ?CONNECT_JIT_CONT_FAIL_COUNT ->
					case connectonetcpserver(TcpServer,TcpPort,Bin) of
						{ok,BinResp} ->
							ets:insert(serverstatetable, {masterjitcontfail,0}),
							ets:insert(serverstatetable, {jitservercontfail,0}),
							%% Since master is ok, send stored msg2http to it.
							connecttcpserverstored(TcpServer,TcpPort,TcpServer2,TcpPort2,true),
							{ok,BinResp};
						{error,Reason} ->
							ets:insert(serverstatetable, {masterjitcontfail,MJitContFail+1}),
							[{masterjittotalfail,MJitTotalFail}] = ets:lookup(serverstatetable, masterjittotalfail),
							ets:insert(serverstatetable, {masterjittotalfail,MJitTotalFail+1}),
							logerror("Master fails and try slave because of ~p~n",Reason),
							connecttcpserver(TcpServer,TcpPort,TcpServer2,TcpPort2,false,Socket,TimeStamp,Bin)
					end
			end;
		UseMaster == false ->
			case connectonetcpserver(TcpServer2,TcpPort2,Bin) of
				{ok,BinResp2} ->
					ets:insert(serverstatetable, {jitservercontfail,0}),
					%% Since slave is ok, send stored msg2http to it.
					connecttcpserverstored(TcpServer,TcpPort,TcpServer2,TcpPort2,false),
					{ok,BinResp2};
				{error,Reason2} ->
					{_,{Address,Port}}=getsafepeername(Socket),
					ets:insert(msg2jittable, {TimeStamp,Address,Port,Bin}),
					[{jitservercontfail,JitContFail}] = ets:lookup(serverstatetable, jitservercontfail),
					ets:insert(serverstatetable, {jitservercontfail,JitContFail+1}),
					[{jitservertotalfail,JitTotalFail}] = ets:lookup(serverstatetable, jitservertotalfail),
					ets:insert(serverstatetable, {jitservertotalfail,JitTotalFail+1}),
					logerror("Both jit server fails because of ~p~n",Reason2),
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
							logerror("Jit server close socket ~p:~p~n", [TcpServer,TcpPort]),
							{error,"Jit server close socket."};
						{tcp_error,Socket} ->
				            logerror("Close jit server socket (~p:~p) because of tcp_error~n", [TcpServer,TcpPort]),
							closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
							{error,"Jit server tcp_error"};
						{tcp_error,Socket,Reason} ->
				            logerror("Close jit server socket (~p:~p) because of tcp_error : ~p~n", [TcpServer,TcpPort,Reason]),
							closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
							{error,Reason};
						Msg ->
							logerror("Close jit server socket (~p:~p) because of unknown state : ~p~n", [TcpServer,TcpPort,Msg]),
							closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
							{error,Msg}
					after ?JIT_TCP_RECEIVE_TIMEOUT ->
						logerror("Close jit server socket (~p:~p) because of no data received after ~p ms~n", [TcpServer,TcpPort,?JIT_TCP_RECEIVE_TIMEOUT]),
						closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
						{error,"Jit server timeout in response"}
					end;
				{error,Reason} ->
					logerror("Close jit server socket (~p:~p) because of sending data to jit server fails : ~p~n",[TcpServer,TcpPort,Reason]),
					closetcpsocket(Socket,lists:flatten(io_lib:format("jit server : ~p:~p",[TcpServer,TcpPort]))),
					{error,Reason}
			catch
                _:Why ->
					logerror("Close jit server socket (~p:~p) because of sending data to jit tcp server exception : ~p~n",[TcpServer,TcpPort,Why]),
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
					BinSent = list_to_binary(Bin);
				false ->
					case is_binary(Bin) of
						true ->
							BinSent = Bin;
						false ->
							logerror("Unknown server data : ~p~n",[Bin]),
							BinSent = ?UNKNWON_SERVER_DATA
					end
			end;
		SendBinary == false ->
			case is_binary(Bin) of
				true ->
					BinSent = binary_to_list(Bin);
				false ->
					case is_list(Bin) of
						true ->
							BinSent = Bin;
						false ->
							logerror("Unknown server data : ~p~n",[Bin]),
							BinSent = ?UNKNWON_SERVER_DATA
					end
			end
	end,
	try gen_tcp:send(Socket,BinSent) of
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
	case safepeername(Socket) of
		{ok,{Address,Port}} ->
			ets:insert(terminstancetable, {Socket,Address,Port,TimeStamp});
		{error,_} ->
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
	case safepeername(Socket) of
		{ok,{Address,Port}} ->
			ets:insert(maninstancetable, {Socket,Address,Port,TimeStamp});
		{error,_} ->
			ets:insert(maninstancetable, {Socket,"0.0.0.0","0",TimeStamp})
	end.

deletemansocket(Socket) ->
	ets:delete(maninstancetable, Socket).

%%
%% default is man term
%%
%% {ok,{Address,Port}} -> Address is string, Port is "0" or number
%% {error,Reason}
%%
%%
safepeername(Socket) ->
	safepeername(Socket,true).

%%
%% {ok,{Address,Port}} -> Address is string, Port is "0" or number
%% {error,Reason}
%%
safepeername(Socket,IsMan) ->
	try inet:peername(Socket) of
		{ok,{Address,Port}} ->
			{ok,{inet_parse:ntoa(Address),Port}};
		{error,Reason} ->
			if
				IsMan == true ->
					logerror("Check man term socket (~p) fails : ~p",[Socket,Reason]);
				IsMan == false ->
					logerror("Check term socket (~p) fails : ~p",[Socket,Reason])
			end,
			{error,Reason}
	catch
		_:Why ->
			if
				IsMan == true ->
					logerror("Check man termsocket (~p) exception : ~p",[Socket,Why]);
				IsMan == false ->
					logerror("Check term socket (~p) exception : ~p",[Socket,Why])
			end,
			{error,Why}
	end.

%%
%% default is man term
%%
%% {ok,{Address,Port}} -> Address is string, Port is "0" or number
%% {error,Reason}
%%
getsafepeername(Socket) ->
	getsafepeername(Socket,true).

%%
%% {ok,{Address,Port}} -> Address is string, Port is "0" or number
%% {error,Reason}
%%
getsafepeername(Socket,IsMan) ->
	case safepeername(Socket,IsMan) of
		{ok,{Address,Port}} ->
			{ok,{Address,Port}};
		{error,_} ->
			{error,{"0.0.0.0","0"}}
	end.

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
