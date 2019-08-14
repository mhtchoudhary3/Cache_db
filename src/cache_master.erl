-module(cache_master).
-author("Mohit").

%% API
-export([start_link/0, test/0, set_cluster_db_nodes/0, 
         set_options/0,	call/4,get_cluster_db_nodes/0,
        set_cluster_db_nodes/1, send_test/1, req_handler/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).			
-behaviour(gen_server).

%-include("logger.hrl").
-define(Net_ticktime, 60).
-define(Rpc_timeout, 5).
-define(INFO_MSG(Format, Args),
        io:format(Format, Args)).

-record(state, {}).
-record(options, {key, val}).
-record(cluster_db, {key, val}).

%%%===================================================================
%%% API
%%%===================================================================
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

test()->
    ?INFO_MSG("cache test started~n", []),
    Msgs = [{{john, 111}, critical},
            {{shyam, 111}, non_critical},
	    {{ram, 111}, non_critical}],
    [send_test(Msg) || Msg <- Msgs],
    ok.
	
send_test(Msg) ->
   ?MODULE ! Msg.
	
call(Nodes, Module, Function, Args) ->
    ?INFO_MSG("cache_server : sending msg  ~p to Node : ~p~n", [Args, Nodes]),
    rpc:call(Nodes, Module, Function, [Args], rpc_timeout()).

set_cluster_db_nodes()->
    set_cluster_db_nodes([]).
	
set_cluster_db_nodes(Nodes) ->
     mnesia:dirty_write({cluster_db,  cluster_db_nodes, Nodes}).

req_handler({Data, Criticality}) ->
     Node = least_busy_node(),
     try call(Node, cache_db, recieve_data, [{Data, Criticality}])
     catch   _:_ -> ?INFO_MSG("cache_server :error at cache db: ~p for  msg  ~p ~n", [Node, {Data, Criticality}]),
                   "error"
     end.


%%%===================================================================
%%% gen_server API
%%%===================================================================
init([]) ->
    catch mnesia:create_schema([node()]),
    mnesia:start(),
    catch set_options(),
    timer:sleep(1000),
    Ticktime = get_option(net_ticktime, ?Net_ticktime),
    Nodes = get_cluster_db_nodes(),
    net_kernel:set_net_ticktime(Ticktime),
     ?INFO_MSG("nodes: ~p ", [Nodes]),
    lists:foreach(fun(Node) ->
                  net_kernel:connect_node(Node)
                  end, Nodes),
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({Data, Criticality}, State) ->
    ?INFO_MSG("cache_server : msg  ~p recieved at node : ~p ~n", [{Data, Criticality}, node()]),
    spawn_link(?MODULE, req_handler, [{Data, Criticality}]),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

rpc_timeout() ->
    timer:seconds(get_option(rpc_timeout, ?Rpc_timeout)).
	


get_option(Opt, Default) ->
    case mnesia:dirty_read(options, Opt) of
        [] -> Default;
        [{_, _, Val}] -> Val
    end.
		
set_options() ->
    mnesia:create_table(options,
                        [{attributes, record_info(fields, options)}]),
    mnesia:create_table(cluster_db,
               [{attributes, record_info(fields, cluster_db)}]),
    mnesia:dirty_write({options,  rpc_timeout, ?Rpc_timeout}),
    mnesia:dirty_write({options,  net_ticktime, ?Net_ticktime}),

    ok.
	
least_busy_node() ->
    case nodes() of
        [] -> false;
        Nodes ->
            lists:nth(random:uniform(length(Nodes)), Nodes)
    end.	
	

get_cluster_db_nodes()->
    case  mnesia:dirty_read(cluster_db, cluster_db_nodes) of
         [] -> set_cluster_db_nodes([cache2@localhost,cache3@localhost]),
		get_cluster_db_nodes();
         [{_, _ ,Nodes}] -> Nodes
            end.

