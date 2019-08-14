# Cache_db
cache_db project is an in-memory data structure project, implementing a distributed, in-memory key-value database with optional durability and scalability. It consists of auto-update trigger functionality between DB nodes.

Below modules are implemented:
cache_master:  Interface server which accepts request(credentials and criticality), and routes it towards cache_dbs
cache_db: It accepts the request from cache_server and saves the data into DB. Based on criticality it updates other cache DBs via synchronous or asynchronous calls.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%            Test Result   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%[cache1@localhost] : cache_master  %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%   [cache2@localhost, cache1@localhost] : cache_db  %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

(cache1@localhost)1>  c(cache_master).
{ok,cache_master}

(cache1@localhost)2>  cache_master:start_link().
nodes: [cache2@localhost,cache3@localhost] {ok,<0.47.0>}

(cache1@localhost)3>  cache_master:test().     
cache test started
cache_server : msg  {{john,111},critical} recieved at node : cache1@localhost 
cache_server : msg  {{shyam,111},non_critical} recieved at node : cache1@localhost 
ok
cache_server : msg  {{ram,111},non_critical} recieved at node : cache1@localhost 
(cache1@localhost)4>     
cache_server : sending msg  [{{john,111},critical}] to Node : cache2@localhost
cache_server : sending msg  [{{shyam,111},non_critical}] to Node : cache2@localhost
cache_server : sending msg  [{{ram,111},non_critical}] to Node : cache2@localhost
msg  {{john,111},critical} recieved at node cache2@localhost 
msg  {{shyam,111},non_critical} recieved at node cache2@localhost 
msg  {{ram,111},non_critical} recieved at node cache2@localhost 
adding msg  {john,111}  at node cache2@localhost 
adding msg  {shyam,111}  at node cache2@localhost 
adding msg  {ram,111}  at node cache2@localhost 
syncing msg  {john,111} via synchronous call from  node cache2@localhost to nodes [cache3@localhost] 
syncing msg  {shyam,111} via asynchronous call from  node cache2@localhost to nodes [cache3@localhost] 
syncing msg  {ram,111} via asynchronous call from  node cache2@localhost to nodes [cache3@localhost] 
adding msg  {john,111}  at node cache3@localhost 
adding msg  {shyam,111}  at node cache3@localhost 
adding msg  {ram,111}  at node cache3@localhost 
