-module(mongoose_muc_online_mnesia).
-export([start/2,
         register_room/4,
         room_destroyed/4,
         find_room_pid/3]).

-include_lib("mod_muc.hrl").

start(_HostType, _Opts) ->
    mnesia:create_table(muc_online_room,
                        [{ram_copies, [node()]},
                         {attributes, record_info(fields, muc_online_room)}]),
    mnesia:add_table_copy(muc_online_room, node(), ram_copies),
    ok.

register_room(HostType, MucHost, Room, Pid) ->
    F = fun() ->
            case mnesia:read(muc_online_room,  {Room, MucHost}, write) of
                [] ->
                    mnesia:write(#muc_online_room{name_host = {Room, MucHost},
                                                  host_type = HostType,
                                                  pid = Pid});
                [R] ->
                    {exists, R#muc_online_room.pid}
            end
        end,
    simple_transaction_result(mnesia:transaction(F)).

%% Race condition is possible between register and room_destroyed
%% (Because register is outside of the room process)
-spec room_destroyed(mongooseim:host_type(), jid:server(), mod_muc:room(), pid()) -> ok.
room_destroyed(HostType, MucHost, Room, Pid) ->
    Obj = #muc_online_room{name_host = {Room, MucHost},
                           host_type = HostType, pid = Pid},
    F = fun() -> mnesia:delete_object(Obj) end,
    {atomic, ok} = mnesia:transaction(F),
    ok.

simple_transaction_result({atomic, Res}) ->
    Res;
simple_transaction_result({aborted, Reason}) ->
    {error, Reason}.

find_room_pid(HostType, MucHost, Room) ->
    case mnesia:dirty_read(muc_online_room, {Room, MucHost}) of
        [R] ->
            {ok, R#muc_online_room.pid};
        [] ->
            {error, not_found}
    end.
