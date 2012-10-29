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
-export([start/0,start/1,start/2,start/7,stop/0]).

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
	start(HttpServer,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,DisplayLog,LogLevel).

start() ->
	start(false).
start(DisplayLog) ->
	start(DisplayLog,?MSG_LEVEL_ERROR).
start(DisplayLog,LogLevel) ->
	start(?HTTP_SERVER_NOPORT,?MASTER_TCP_SERVER,?MASTER_TCP_SERVER_PORT,?SLAVE_TCP_SERVER,?SLAVE_TCP_SERVER_PORT,DisplayLog,LogLevel).
start(HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,DisplayLog,LogLevel) ->
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
			loginfo("Server start~n"),
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
			loginfo("Server management start~n"),
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
			loginfo("Server http client start~n");
		{error,ReasonInets} ->
			logerror("Server http client fails : ~p and exits~n",[ReasonInets]),
			exit(ReasonInets)
	catch
		_:WhyInets ->
			logerror("Server http client exception : ~p and exits~n",[WhyInets]),
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
	ets:delete(serverlogtable),
	ets:delete(msg2terminaltable),
	ets:delete(maninstancetable),
	ets:delete(terminstancetable),
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
	ets:insert(serverstatetable,{httpserverfail,0}),
	ets:insert(serverstatetable,{accepttermcontfail,0}),
	ets:insert(serverstatetable,{accepttermtotalfail,0}),
	ets:insert(serverstatetable,{acceptmancontfail,0}),
	ets:insert(serverstatetable,{acceptmantotalfail,0}),
	ets:insert(serverstatetable,{logserverlevel,LogLevel}),
	ets:insert(serverstatetable,{orilogserverlevel,LogLevel}),
	ets:insert(serverstatetable,{mantermcount,0}),
	ets:insert(serverstatetable,{termcount,0}),
	ets:new(msg2terminaltable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(msg2jittable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(maninstancetable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(terminstancetable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(msg2httptable,[duplicate_bag,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(serverlogtable,[duplicate_bag,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]).

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
							[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
							ets:insert(serverstatetable, {mantermcount,ManCount+1}),
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
					[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
					ets:insert(serverstatetable, {mantermcount,ManCount-1})
			end;
		{tcp_closed,Socket} ->
			%%logerror("Man-term close socket (~p)~n", [Socket]),
			[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
			ets:insert(serverstatetable, {mantermcount,ManCount-1});
		{tcp_error,Socket} ->
			logerror("Man-term socket (~p) tcp_error~n", [Socket]),
			logerror("Close man-term socket~n"),
			%% !!!
			%% Should server send message to management terminal before close?
			%% If so, please check which kind of message
			%% Does tcp_error mean that server cannot send data to management terminal?
			%% !!!
			closetcpsocket(Socket,"man-term"),
			[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
			ets:insert(serverstatetable, {mantermcount,ManCount-1});
		Msg ->
			logerror("Unknown server state for man-term socket (~p) : ~p~n", [Socket,Msg]),
			logerror("Close man-term socket~n"),
			%% !!!
			%% Should server send message to management terminal before close?
			%% If so, please check which kind of message
			%% !!!
			connectmanterm(Socket,?UNKNWON_SOCKET_STATE),
			closetcpsocket(Socket,"man-term"),
			[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
			ets:insert(serverstatetable, {mantermcount,ManCount-1})
 	after ?MT_TCP_RECEIVE_TIMEOUT ->
		logerror("No data from man-term (~p) after ~p ms~n", [Socket,?MT_TCP_RECEIVE_TIMEOUT]),
		logerror("Close man-term socket~n"),
		connectmanterm(Socket,?UNKNWON_TERMINAL_STATE),
		closetcpsocket(Socket,"man-term"),
		[{mantermcount,ManCount}] = ets:lookup(serverstatetable, mantermcount),
		ets:insert(serverstatetable, {mantermcount,ManCount-1})
	end.

%%
%% Header (2 byte : 2 * 8)
%% Sub Header (4 bytes : 4 * 8)
%% Body
%%
processmanagementdata(Bin) ->
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
							try ets:insert(serverstatetable, {acceptmancontfail,0}) of
								true ->
									?MT_CLR_ACC_MT_CONT_FAIL_OK;
								_ ->
									?MT_CLR_ACC_MT_CONT_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_ACC_MT_CONT_FAIL_ERR, Why)
							end;
						?MT_CLR_ACC_MT_TOTAL_FAIL->
							try ets:insert(serverstatetable, {acceptmantotalfail,0}) of
								true ->
									?MT_CLR_ACC_MT_TOTAL_FAIL_OK;
								_ ->
									?MT_CLR_ACC_MT_TOTAL_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_ACC_MT_TOTAL_FAIL_ERR, Why)
							end;
						?MT_CLR_ACC_TERM_CONT_FAIL ->
							try ets:insert(serverstatetable, {accepttermcontfail,0}) of
								true ->
									?MT_CLR_ACC_TERM_CONT_FAIL_OK;
								_ ->
									?MT_CLR_ACC_TERM_CONT_FAIL_ERR
							catch
								_:Why ->
								  string:concat(?MT_CLR_ACC_TERM_CONT_FAIL_ERR, Why)
							end;
						?MT_CLR_ACC_TERM_TOTAL_FAIL ->
							try ets:insert(serverstatetable, {accepttermtotalfail,0}) of
								true ->
									?MT_CLR_ACC_TERM_TOTAL_FAIL_OK;
								_ ->
									?MT_CLR_ACC_TERM_TOTAL_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_ACC_TERM_TOTAL_FAIL_ERR, Why)
							end;
						?MT_CLR_ALL_2HTTP ->
							try	ets:delete_all_objects(msg2httptable) of
								true ->
									?MT_CLR_ALL_2HTTP_OK;
								_ ->
									?MT_CLR_ALL_2HTTP_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_ALL_2HTTP_ERR, Why)
							end;
						?MT_CLR_ALL_2JIT ->
							try	ets:delete_all_objects(msg2jittable) of
								true ->
									?MT_CLR_ALL_2JIT_OK;
								_ ->
									?MT_CLR_ALL_2JIT_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_ALL_2JIT_ERR, Why)
							end;
						?MT_CLR_ALL_2TERM ->
							try	ets:delete_all_objects(msg2terminaltable) of
								true ->
									?MT_CLR_ALL_2TERM_OK;
								_ ->
									?MT_CLR_ALL_2TERM_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_ALL_2TERM_ERR, Why)
							end;
						?MT_CLR_BOTH_JIT_FAIL ->
							try ets:insert(serverstatetable, {jitserverfail,0}) of
								true ->
									?MT_CLR_BOTH_JIT_FAIL_OK;
								_ ->
									?MT_CLR_BOTH_JIT_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_BOTH_JIT_FAIL_ERR, Why)
							end;
						?MT_CLR_MASTER_JIT_FAIL ->
							try ets:insert(serverstatetable, {masterjitfail,0}) of
								true ->
									?MT_CLR_MASTER_JIT_FAIL_OK;
								_ ->
									?MT_CLR_MASTER_JIT_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_MASTER_JIT_FAIL_ERR, Why)
							end;
						?MT_QRY_ACC_MT_CONT_FAIL ->
							try ets:lookup(serverstatetable, acceptmancontfail) of
								[{acceptmancontfail,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ACC_MT_CONT_FAIL_OK, Str);
								_ ->
									?MT_QRY_ACC_MT_CONT_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_QRY_ACC_MT_CONT_FAIL_ERR, Why)
							end;
						?MT_QRY_ACC_MT_TOTAL_FAIL ->
							try ets:lookup(serverstatetable, acceptmantotalfail) of
								[{acceptmantotalfail,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ACC_MT_TOTAL_FAIL_OK, Str);
								_ ->
									?MT_QRY_ACC_MT_TOTAL_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_QRY_ACC_MT_TOTAL_FAIL_ERR, Why)
							end;
						?MT_QRY_ACC_TERM_CONT_FAIL ->
							try ets:lookup(serverstatetable, accepttermcontfail) of
								[{accepttermcontfail,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ACC_TERM_CONT_FAIL_OK, Str);
								_ ->
									?MT_QRY_ACC_TERM_CONT_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_QRY_ACC_TERM_CONT_FAIL_ERR, Why)
							end;
						?MT_QRY_ACC_TERM_TOTAL_FAIL ->
							try ets:lookup(serverstatetable, accepttermtotalfail) of
								[{accepttermtotalfail,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ACC_TERM_TOTAL_FAIL_OK, Str);
								_ ->
									?MT_QRY_ACC_TERM_TOTAL_FAIL_ERR
							catch
								_:Why ->
									string:concat(?MT_QRY_ACC_TERM_TOTAL_FAIL_ERR, Why)
							end;
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
							try ets:select_count(msg2httptable, [{{'$1','$2','$3'},[],[true]}]) of
								Value ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ALL_2HTTP_COUNT_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ALL_2HTTP_COUNT_ERR, Why)
							end;
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
							try ets:select_count(msg2jittable, [{{'$1','$2','$3'},[],[true]}]) of
								Value ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ALL_2JIT_COUNT_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ALL_2JIT_COUNT_ERR, Why)
							end;
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
							try ets:select_count(msg2terminaltable, [{{'$1','$2','$3'},[],[true]}]) of
								Value ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ALL_2TERM_COUNT_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ALL_2TERM_COUNT_ERR, Why)
							end;
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
							try ets:select_count(serverlogtable, [{{'$1','$2','$3'},[],[true]}]) of
								Value ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ALL_LOG_COUNT_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ALL_LOG_COUNT_ERR, Why)
							end;
						?MT_CLR_ALL_LOG ->
							try	ets:delete_all_objects(serverlogtable) of
								true ->
									?MT_CLR_ALL_LOG_OK;
								_ ->
									?MT_CLR_ALL_LOG_ERR
							catch
								_:Why ->
									string:concat(?MT_CLR_ALL_LOG_ERR, Why)
							end;
						?MT_QRY_ALL_STATES ->
							case getallstates() of
								{ok,States} ->
									string:concat(?MT_QRY_ALL_STATES_OK, States);
								{error,Why} ->
									string:concat(?MT_QRY_ALL_STATES_ERR, Why)
							end;
						?MT_QRY_BOTH_JIT_FAIL ->
							try ets:lookup(serverstatetable, jitserverfail) of
								[{jitserverfail,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_BOTH_JIT_FAIL_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_BOTH_JIT_FAIL_ERR, Why)
							end;
						?MT_QRY_DISPLAY_LOG_STATE ->
							try ets:lookup(serverstatetable, displaylog) of
								[{displaylog,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_DISPLAY_LOG_STATE_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_DISPLAY_LOG_STATE_ERR, Why)
							end;
						?MT_QRY_LOG_LEVEL ->
							try ets:lookup(serverstatetable, logserverlevel) of
								[{logserverlevel,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_LOG_LEVEL_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_LOG_LEVEL_ERR, Why)
							end;
						?MT_QRY_MASTER_JIT_FAIL ->
							try ets:lookup(serverstatetable, masterjitfail) of
								[{masterjitfail,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_MASTER_JIT_FAIL_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_MASTER_JIT_FAIL_ERR, Why)
							end;
						?MT_QRY_USE_MASTER_STATE ->
							try ets:lookup(serverstatetable, usemasterjit) of
								[{usemasterjit,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_USE_MASTER_STATE_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_USE_MASTER_STATE_ERR, Why)
							end;
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
									try ets:insert(serverstatetable, {displaylog,true}) of
										true ->
											?MT_SET_DISPLAY_LOG_STATE_OK;
										_ ->
											?MT_SET_DISPLAY_LOG_STATE_ERR
									catch
										_:Why ->
											string:concat(?MT_SET_DISPLAY_LOG_STATE_ERR, Why)
									end;
								"0" ->
									try ets:insert(serverstatetable, {displaylog,false}) of
										true ->
											?MT_SET_DISPLAY_LOG_STATE_OK;
										_ ->
											?MT_SET_DISPLAY_LOG_STATE_ERR
									catch
										_:Why ->
											string:concat(?MT_SET_DISPLAY_LOG_STATE_ERR, Why)
									end;
								_ ->
									string:concat(?MT_UNK_MT_DATA, Body)
							end;
						?MT_SET_LOG_LEVEL ->
							case Body of
								 "0" ->
									try ets:insert(serverstatetable, {logserverlevel,0}) of
										true ->
											?MT_SET_LOG_LEVEL_OK;
										_ ->
											?MT_SET_LOG_LEVEL_ERR
									catch
										_:Why ->
											string:concat(?MT_SET_LOG_LEVEL_ERR, Why)
									end;
								"1" ->
									try ets:insert(serverstatetable, {logserverlevel,1}) of
										true ->
											?MT_SET_LOG_LEVEL_OK;
										_ ->
											?MT_SET_LOG_LEVEL_ERR
									catch
										_:Why ->
											string:concat(?MT_SET_LOG_LEVEL_ERR, Why)
									end;
								"2" ->
									try ets:insert(serverstatetable, {logserverlevel,2}) of
										true ->
											?MT_SET_LOG_LEVEL_OK;
										_ ->
											?MT_SET_LOG_LEVEL_ERR
									catch
										_:Why ->
											string:concat(?MT_SET_LOG_LEVEL_ERR, Why)
									end;
								_ ->
									string:concat(?MT_UNK_MT_DATA, Body)
							end;
						?MT_SET_USE_MASTER_STATE ->
							case Body of
								 "1" ->
									try ets:insert(serverstatetable, {usemasterjit,true}) of
										true ->
											?MT_SET_USE_MASTER_STATE_OK;
										_ ->
											?MT_SET_USE_MASTER_STATE_ERR
									catch
										_:Why ->
											string:concat(?MT_SET_USE_MASTER_STATE_ERR, Why)
									end;
								"0" ->
									try ets:insert(serverstatetable, {usemasterjit,false}) of
										true ->
											?MT_SET_USE_MASTER_STATE_OK;
										_ ->
											?MT_SET_USE_MASTER_STATE_ERR
									catch
										_:Why ->
											string:concat(?MT_SET_USE_MASTER_STATE_ERR, Why)
									end;
								_ ->
									string:concat(?MT_UNK_MT_DATA, Body)
							end;
						?MT_QRY_ALL_MT ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_MT_ERR;
						?MT_QRY_ALL_MT_COUNT ->
							%% !!!
							%% Need further job here because we don't know the message format in msg2terminaltable
							%% !!!
							try ets:select_count(maninstancetable, [{{'$1'},[],[true]}]) of
								Value ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ALL_MT_COUNT_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ALL_MT_COUNT_ERR, Why)
							end;
						?MT_QRY_ALL_MT_TAB_COUNT ->
							try ets:lookup(serverstatetable, mantermcount) of
								[{mantermcount,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ALL_MT_TAB_COUNT_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ALL_MT_TAB_COUNT_ERR, Why)
							end;
						?MT_QRY_ORI_DISPLAY_LOG_STATE ->
							try ets:lookup(serverstatetable, oridisplaylog) of
								[{oridisplaylog,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ORI_DISPLAY_LOG_STATE_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ORI_DISPLAY_LOG_STATE_ERR, Why)
							end;
						?MT_QRY_ORI_LOG_LEVEL ->
							try ets:lookup(serverstatetable, orilogserverlevel) of
								[{orilogserverlevel,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ORI_LOG_LEVEL_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ORI_LOG_LEVEL_ERR, Why)
							end;
						?MT_QRY_ALL_TERM ->
							%% !!!
							%% Need further job here
							%% !!!
							?MT_QRY_ALL_TERM_ERR;
						?MT_QRY_ALL_TERM_COUNT ->
							%% !!!
							%% Need further job here because we don't know the message format in msg2terminaltable
							%% !!!
							try ets:select_count(terminstancetable, [{{'$1'},[],[true]}]) of
								Value ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ALL_TERM_COUNT_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ALL_TERM_COUNT_ERR, Why)
							end;
						?MT_QRY_ALL_TERM_TAB_COUNT ->
							try ets:lookup(serverstatetable, termcount) of
								[{termcount,Value}] ->
									Str=io_lib:format("~p", Value),
									string:concat(?MT_QRY_ALL_TERM_TAB_COUNT_OK, Str)
							catch
								_:Why ->
									string:concat(?MT_QRY_ALL_TERM_TAB_COUNT_ERR, Why)
							end;
						_ ->
							string:concat(?MT_UNK_REQ_ERR,BinStr)
					end
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
	[{httpserverfail,HttpFC}] = ets:lookup(serverstatetable,httpserverfail),
	S50 = string:concat(S4, ";HttpFC:"),
	S5 = string:concat(S50, integer_to_list(HttpFC)),
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
	MTermInstCount = ets:select_count(maninstancetable, [{{'$1'},[],[true]}]),
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
	[{termcount,TermCount}] = ets:lookup(serverstatetable,termcount),
	S180= string:concat(S17, ";TermCount:"),
	S18 = string:concat(S180, integer_to_list(TermCount)),
	[{mantermcount,MTermCount}] = ets:lookup(serverstatetable,mantermcount),
	S190= string:concat(S18, ";MTermCount:"),
	S19 = string:concat(S190, integer_to_list(MTermCount)),
	TermInstCount = ets:select_count(terminstancetable, [{{'$1'},[],[true]}]),
	S200= string:concat(S19, ";TermInstCount:"),
	S20 = string:concat(S200, integer_to_list(TermInstCount)),
	{ok,S20}.	

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
	ets:insert(serverstatetable,{httpserverfail,0}),
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
							[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
							ets:insert(serverstatetable, {termcount,TermCount+1}),
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
			%% It is safe for the same terminal because each terminal is not allowed to report very frequenctly.
			%% The time interval is 60m which is needed to be checked with the planner.
			TimeStamp = calendar:now_to_local_time(erlang:now()),
			%%loginfo("Data from term",Bin),
			case httpservermessage(Bin) of
				true ->
		            HttpBin = dataprocessor:tcp2http(Bin),
					%%loginfo("Data to http server : ~p~n",HttpBin),
					HttpMsgCount=ets:select_count(msg2httptable, [{{'$1','$2','$3'},[],[true]}]),
					%%loginfo("Already stored msg2http message count : ~p~n",[HttpMsgCount]),
					[{httpserverfail,HttpFC}] = ets:lookup(serverstatetable, httpserverfail),
					if
						HttpFC > ?CONNECT_HTTP_MAX_COUNT ->
							%% !!!
							%% We need to report this status to the terminal
							%% How do we define this message data?
							%% !!!
							logerror("~p continous failures in http server and msg2http&msg2jit will be stored~n",[?CONNECT_HTTP_MAX_COUNT]),
							ets:insert(msg2httptable, {TimeStamp,Socket,HttpBin}),
							ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
							if
								HttpMsgCount > ?TO_HTTP_MAX_MESSAGE_COUNT -> %% Should these data be saved and the msg2httptable be cleared?
									ok;
								HttpMsgCount =< ?TO_HTTP_MAX_MESSAGE_COUNT ->
									ok
							end;
						HttpFC =< ?CONNECT_HTTP_MAX_COUNT ->
							case connecthttpserver(HttpServer,Socket,TimeStamp,HttpBin) of
								ok ->
									doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin);
								{error,Reason} ->
									logerror("Store msg2jit~n"),
									ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
									%% !!!
									%% Should send message to terminal before close
									%% Please check which kind of message
									%% !!!
									HttpError = string:concat(?MT_HTTP_FAILURE, Reason),
									connectterm(Socket,HttpError),
									closetcpsocket(Socket,"term"),
									[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
									ets:insert(serverstatetable, {termcount,TermCount-1})
							end
					end;
				false ->
					doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin)
			end;
		{tcp_closed,Socket} ->
			%%logerror("Term close socket (~p)~n", [Socket]),
			[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
			ets:insert(serverstatetable, {termcount,TermCount-1});
		{tcp_error,Socket} ->
			logerror("Term socket (~p) tcp_error~n", [Socket]),
			%% !!!
			%% Should server send message to terminal before close?
			%% If so, please check which kind of message
			%% Does tcp_error mean that server cannot send data to terminal?
			%% !!!
			closetcpsocket(Socket,"term"),
			[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
			ets:insert(serverstatetable, {termcount,TermCount-1});
		Msg ->
			logerror("Unknown server state for term socket (~p) : ~p~n", [Socket,Msg]),
			%% !!!
			%% Should server send message to terminal before close?
			%% If so, please check which kind of message
			%% !!!
			connectterm(Socket,?UNKNWON_SOCKET_STATE),
			closetcpsocket(Socket,"term"),
			[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
			ets:insert(serverstatetable, {termcount,TermCount-1})
 	after ?TERM_TCP_RECEIVE_TIMEOUT ->
		logerror("No data from term (~p) after ~p ms~n", [Socket,?TERM_TCP_RECEIVE_TIMEOUT]),
		connectterm(Socket,?UNKNWON_TERMINAL_STATE),
		closetcpsocket(Socket,"term"),
		[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
		ets:insert(serverstatetable, {termcount,TermCount-1})
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
	[{httpserverfail,HttpFC}] = ets:lookup(serverstatetable, httpserverfail),
	%% !!!
	%% Please check the parameters of the method httpc:request(...)
	%% !!!
	ContentType = "text/json",
	Options = [{body_format,binary}],
	try httpc:request(post,{HttpServer,[],ContentType,Bin},[],Options) of
		{ok,_} ->
			%% !!!
			%% Since http server is ok, send the stored msg2http to it
			%% !!!
			ets:insert(serverstatetable, {httpserverfail,0}),
			connecthttpserverstored(HttpServer),
			ok;
		{error,Reason} ->
			logerror("Requesting http server fail : ~p~n",[Reason]),
			logerror("Store msg2http~n"),
			%% !!!
			%% We need to report this status to the terminal
			%% How do we define this message data?
			%% !!!
			ets:insert(serverstatetable, {httpserverfail,HttpFC+1}),
			ets:insert(msg2httptable, {TimeStamp,Socket,Bin}),
			{error,Reason}
	catch
		_:Why ->
			logerror("Requesting http server exception : ~p~n",[Why]),
			logerror("Store msg2http~n"),
			%% !!!
			%% We need to report this status to the terminal
			%% How do we define this message data?
			%% !!!
			ets:insert(serverstatetable, {httpserverfail,HttpFC+1}),
			ets:insert(msg2httptable, {TimeStamp,Socket,Bin}),
			{error,Why}
	end.

connecthttpserverstored(HttpServer) ->
	HttpServer,
	ok.

doconnecttcpserver(Socket,HttpServer,TcpServer,TcpPort,TcpServer2,TcpPort2,Socket,TimeStamp,Bin) ->
	JitMsgCount=ets:select_count(msg2jittable, [{{'$1','$2','$3'},[],[true]}]),
	%%loginfo("Already stored msg2jit message count : ~p~n",[JitMsgCount]),
	[{jitserverfail,JitFC}] = ets:lookup(serverstatetable, jitserverfail),
	if
		JitFC > ?CONNECT_JIT_MAX_COUNT ->
			%% !!!
			%% We need to report this status to the terminal
			%% How do we define this message data?
			%% !!!
			logerror("~p continous failures in both jit servers and msg2jit will be stored~n",[?CONNECT_HTTP_MAX_COUNT]),
			ets:insert(msg2jittable, {TimeStamp,Socket,Bin}),
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
			closetcpsocket(Socket,"term"),
			[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
			ets:insert(serverstatetable, {termcount,TermCount-1});
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
							logerror("Close term socket~n"),
							closetcpsocket(Socket,"term"),
							[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
							ets:insert(serverstatetable, {termcount,TermCount-1})
					end;
				error ->
					logerror("Both jit servers error~n"),
					%% !!!
					%% Should send message to terminal before close
					%% Please check which kind of message
					%% !!!
					connectterm(Socket,?MT_JIT_FAILURE),
					closetcpsocket(Socket,"term"),
					[{termcount,TermCount}] = ets:lookup(serverstatetable, termcount),
					ets:insert(serverstatetable, {termcount,TermCount-1})
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
				error ->
					logerror("Master fails and try slave~n"),
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
				error ->
					logerror("Slave jit server fails and store msg2jit~n"),
					%% !!!
					%% We need to report this status to the terminal
					%% How do we define this message data?
					%% !!!
					[{jitserverfail,JitFC}] = ets:lookup(serverstatetable, jitserverfail),
					ets:insert(serverstatetable, {jitserverfail,JitFC+1}),
					ets:insert(msg2jittable,{TimeStamp,Socket,Bin}),
					error
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
							%%loginfo("Close jit server socket (~p)~n", [Socket]),
							closetcpsocket(Socket,"jit server"),
							{ok,BinResp};
						{tcp_closed,Socket} ->
							logerror("Jit server close socket (~p)~n", [Socket]),
							{error,"JIT server close socket."};
						{tcp_error,Socket,Reason} ->
				            logerror("Jit server socket (~p) error : ~p~n", [Socket,Reason]),
							logerror("Close jit server socket~n"),
							closetcpsocket(Socket,"jit server"),
							{error,Reason};
						Msg ->
							logerror("Unknown server state for jit server socket (~p) : ~p~n", [Socket,Msg]),
							logerror("Close jit server socket~n"),
							closetcpsocket(Socket,"jit server"),
							{error,Msg}
					after ?JIT_TCP_RECEIVE_TIMEOUT ->
						logerror("No data from jit server (~p) after ~p ms~n", [Socket,?JIT_TCP_RECEIVE_TIMEOUT]),
						logerror("Close jit server socket~n"),
						closetcpsocket(Socket,"jit server"),
						{error,"JIT server timeout in response"}
					end;
				{error,Reason} ->
					logerror("Send data to jit server (~p) fails : ~p~n",[Socket,Reason]),
					logerror("Close jit server socket~n"),
					closetcpsocket(Socket,"jit tcp server"),
					{error,Reason}
			catch
                _:Why ->
					logerror("Send data to jit tcp server (~p) exception : ~p~n",[Socket,Why]),
					logerror("Close jit server socket~n"),
					closetcpsocket(Socket,"jit server"),
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

%% Each time when the server startup,
%% the saved old requests should first be processed.
processsavedrequests() ->
	ok.

loginfo(Format) ->
	logserver(Format,?MSG_LEVEL_INFO).

%%loginfo(Format,Data) ->
%%	logserver(Format,Data,?MSG_LEVEL_INFO).

%%logwarning(Format) ->
%%	logserver(Format,?MSG_LEVEL_WARNING).

%%logwarning(Format,Data) ->
%%	logserver(Format,Data,?MSG_LEVEL_WARNING).

logerror(Format) ->
	logserver(Format,?MSG_LEVEL_ERROR).

logerror(Format,Data) ->
	logserver(Format,Data,?MSG_LEVEL_ERROR).

logserver(Format,Data,Level) ->
	try io_lib:format(Format, Data) of
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
			logserver(Format,Level),
			logserver(Data,Level)
	end.
	
logserver(FormatData,Level) ->
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
