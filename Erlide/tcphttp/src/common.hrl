%%
%% Server log level
%%
-define(MSG_LEVEL_INFO,(0)).
-define(MSG_LEVEL_WARNING,(1)).
-define(MSG_LEVEL_ERROR,(2)).

-define(ACCEPT_MT_ERROR_CONT_MAX,(3)).
-define(ACCEPT_TERM_ERROR_CONT_MAX,(10)).
-define(CONNECT_JIT_CONT_FAIL_COUNT,(100)).

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

-define(TO_HTTP_MAX_MESSAGE_COUNT,(1000)).
-define(TO_HTTP_WARN_MESSAGE_COUNT,(500)).
-define(TO_JIT_MAX_MESSAGE_COUNT,(100)).

-define(HTTP_DISPATCHER_TIME_INTERVAL_MS,(10000)).

-define(HTTP_PROCESSES_COUNT,(1000)).
-define(HTTP_PROCESSES_MIN_COUNT,(100)).
-define(HTTP_PROCESSES_MAX_COUNT,(1000)).

-record(terminfo,{socket,address="0.0.0.0",port=0,timestamp}). 
 
