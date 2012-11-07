%%
%% Server log level
%%
-define(MSG_LEVEL_INFO,(0)).
-define(MSG_LEVEL_WARNING,(1)).
-define(MSG_LEVEL_ERROR,(2)).

-define(ACCEPT_ERROR_CONT_MAX,(10)).
-define(ACCEPT_ERROR_TOTAL_MAX,(100)).

%% Send the message from the terminal to the http server
-define(CONNECT_HTTP_WARN_COUNT,(100)).
%% Send the message from the terminal to the two jit servers
-define(CONNECT_JIT_MAX_COUNT,(3)).
%% Send the message from the jit server to the terminal
%%-define(REPONSE_TERMINAL_MAX_COUNT,(3)).

-define(TERM_TCP_RECEIVE_TIMEOUT,(90000)).
-define(MT_TCP_RECEIVE_TIMEOUT,(60000)).
-define(JIT_TCP_RECEIVE_TIMEOUT,(10000)).

-define(HTTP_SERVER,("http://127.0.0.1:8080")).
-define(HTTP_SERVER_HOSTNAME,("http://localhost:8080")).
-define(HTTP_SERVER_NOPORT,("http://127.0.0.1")).
-define(HTTP_SERVER_HOSTNAME_NOPORT,("http://localhost")).

-define(TERM_LISTEN_PORT,(5080)).
-define(MT_LISTEN_PORT,(5081)).

-define(MASTER_TCP_SERVER,("127.0.0.1")).
-define(MASTER_TCP_SERVER_PORT,(5082)).
-define(SLAVE_TCP_SERVER,("127.0.0.1")).
-define(SLAVE_TCP_SERVER_PORT,(5082)).

-define(TO_HTTP_MAX_MESSAGE_COUNT,(10000)).
-define(TO_HTTP_WARN_MESSAGE_COUNT,(9000)).
-define(TO_JIT_MAX_MESSAGE_COUNT,(100)).

-define(HTTP_DISPATCHER_TIME_INTERVAL_MS,(1000)).

-define(HTTP_PROCESSES_COUNT,(1000)).
-define(HTTP_PROCESSES_MIN_COUNT,(100)).
-define(HTTP_PROCESSES_MAX_COUNT,(1000)).

-define(JIT_PROCESSES_COUNT,(1000)).

-record(terminfo,{socket,address="0.0.0.0",port=0,timestamp}). 
 
