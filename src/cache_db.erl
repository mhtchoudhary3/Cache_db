-module(cache_db).
-author("mohit").

%% API
-export([start_link/0,  recieve_data/1, set_cluster_db_nodes/0, 
         sync_monitor/2, set_cluster_db_nodes/1, get_cluster_db_nodes/0,
         set_options/0, call/4,	 add_data/1, update_trigger_to_othe_cache_dbs/2,
        recieve_update_trigger/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).					

-behaviour(gen_server).

-define(Net_ticktime, 60).
-define(Rpc_timeout, 5).
-define(INFO_MSG(Format, Args),
        io:format(Format, Args)).

-record(credentials, {key, val}).		
-record(options, {key, val}). 
-record(cluster_db, {key, val}). 

%-include("logger.hrl").

%%%===================================================================
%%% API
%%%===================================================================
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


call([Node], Module, Function, Args) ->
    rpc:multicall([Node], Module, Function, [Args],rpc_timeout());
	
call(Node, Module, Function, Args) ->
    rpc:call(Node, Module, Function, [Args], rpc_timeout()).

set_cluster_db_nodes()->
    set_cluster_db_nodes([]).
	
set_cluster_db_nodes(Nodes) ->
    mnesia:dirty_write({cluster_db,  cluster_db_nodes, Nodes}).	

recieve_data([{Data, Criticality}]) ->
    recieve_data({Data, Criticality});
recieve_data({Data, Criticality})->
    ?INFO_MSG("msg  ~p recieved at node ~p ~n", [{Data, Criticality}, node()]),	
    add_data(Data),
    update_trigger_to_othe_cache_dbs(Data, Criticality),
    ok.

add_data({Key, Val})->
    ?INFO_MSG("adding msg  ~p  at node ~p ~n", [{Key, Val}, node()]),
     mnesia:dirty_write({credentials,  Key, Val}).

%%%%%%% Criticl Trigger : Synchrounous call %%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
update_trigger_to_othe_cache_dbs(Data, critical)->
    Dest = get_cluster_db_nodes() -- [node()],
    ?INFO_MSG("syncing msg  ~p via synchronous call from  node ~p to nodes ~p ~n",
              [Data, node(), Dest]),
    %% synchronous_call;
    case catch call(Dest, cache_db, recieve_update_trigger, Data) of 
        {[ok],[]}-> ok;
	 _ -> update_trigger_to_othe_cache_dbs(Data, critical)
    end;
	
%%%%%%% Non Criticl Trigger : Asynchrounous call %%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
update_trigger_to_othe_cache_dbs(Data, _)->
    Dests = get_cluster_db_nodes() -- [node()],	
    ?INFO_MSG("syncing msg  ~p via asynchronous call from  node ~p to nodes ~p ~n", [Data, node(), Dests]),
    Keys_dest = [{rpc:async_call(Dest, cache_db, recieve_update_trigger, [Data]), Dest }|| Dest<- Dests] ,
    spawn_link(?MODULE, sync_monitor, [Keys_dest,Data]).
   

recieve_update_trigger(Data)->
   add_data(Data),
   ok.
	
sync_monitor([{Key, Dest} | Key_rest], Data)->	
   case	rpc:nb_yield(Key, 5000) of
       	{value, {badrpc, Reason}}->
            ?INFO_MSG(" UnSuccessful : syncing msg  ~p via asynchronous call from  node ~p to nodes ~p ~n", 
                      [Data, node(), Dest]),
	    {badrpc, Reason};
	timeout -> 
            sync_monitor(Key_rest ++ [{Key, Dest}],Data);
        _ ->  
           ?INFO_MSG(" Successful : syncing msg  ~p via asynchronous call from  node ~p to nodes ~p ~n",
                     [Data, node(), Dest]),
           sync_monitor(Key_rest ,Data)
   end.

%%%===================================================================
%%% gen_server API
%%%===================================================================
init([]) ->
    catch mnesia:create_schema([node()]),
    mnesia:start(),
    catch set_options(),
    timer:sleep(200),
    Ticktime = get_option(net_ticktime, ?Net_ticktime),
    Nodes = get_cluster_db_nodes(),
    net_kernel:set_net_ticktime(Ticktime),
    lists:foreach(fun(Node) ->
                      net_kernel:connect_node(Node)
                  end, Nodes),
    {ok, state}.	
	
get_option(Opt, Default) ->
    case mnesia:dirty_read(options, Opt) of
	[] -> Default;
	[{_, _, Val}] -> Val
    end.
		
set_options() ->
    mnesia:create_table(options,
             [{attributes, record_info(fields, options)}]),
    mnesia:create_table(credentials,[{attributes, record_info(fields,credentials)}]),
    mnesia:create_table(cluster_db,
            [{attributes, record_info(fields, cluster_db)}]),
    mnesia:dirty_write({options,  rpc_timeout, ?Rpc_timeout}),	 
    mnesia:dirty_write({options,  net_ticktime, ?Net_ticktime}),  
    ok.


handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

get_cluster_db_nodes()->
    case  mnesia:dirty_read(cluster_db, cluster_db_nodes) of
        [] -> set_cluster_db_nodes([cache2@localhost,cache3@localhost]),
              get_cluster_db_nodes();
        [{_, _ ,Nodes}] -> Nodes
    end.

rpc_timeout() ->
    timer:seconds(get_option(rpc_timeout, ?Rpc_timeout)).
