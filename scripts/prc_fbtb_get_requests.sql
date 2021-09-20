set term ^ ;

create or alter procedure fbtb_get_requests
returns(
    request_id type of column fbtb_command_request.request_id
    , result_text type of column fbtb_command_request.result_text
    , url type of column fbtb_command_request.url
    , http_method type of column fbtb_command_request.http_method
)
as
declare bot_id type of column fbtb_bot.bot_id;
declare messages_per_day_limit type of column fbtb_bot.messages_per_day_limit;
-- Constants
-- -- status of command request
declare UNPROCESSED type of column fbtb_command_request.status = 0;
declare PREPARED type of column fbtb_command_request.status = 1;
declare SENT type of column fbtb_command_request.status = 2;
declare SKIPPED type of column fbtb_command_request.status = 3;
declare FAILED type of column fbtb_command_request.status = 4;
begin
    -- get all unsent `sendMessage` requests
    for select
            r.request_id
            , r.result_text
            , r.url
            , r.http_method
        from fbtb_command_request as r
            left join fbtb_command_subscription as s using(subscription_id)
        where r.status = :UNPROCESSED
            and (s.subscription_id is null
                or current_timestamp between
                    coalesce(s.start_date, current_date) + coalesce(s.from_time, cast(current_timestamp as time))
                        and coalesce(s.end_date, current_date) + coalesce(s.to_time, cast(current_timestamp as time))
            )
            into request_id, result_text, url, http_method
    do
    begin
        suspend;
    end

    -- makes `getUpdates` requests for each enabled bot according to messages per day limit
    for select
            b.bot_id
            , null as result_text
            , 'https://api.telegram.org/bot'|| b.bot_token || '/getUpdates' as url
            , 'GET' as http_method
            , coalesce(b.messages_per_day_limit, 0)
        from fbtb_bot as b
        where b.enabled > 0
            and dateadd(b.update_delay_in_milliseconds millisecond to b.last_updates) < current_timestamp
        into bot_id, result_text, url, http_method, messages_per_day_limit
    do
    begin
        request_id = -bot_id;

        if (messages_per_day_limit = 0
                or messages_per_day_limit > (select count(distinct r.request_id)
                                                from fbtb_command as c
                                                    inner join fbtb_command_request as r using(command_id)
                                                where c.bot_id = :bot_id
                                                    and r.status = :SENT
                                                    and cast(r.status_updated as date) = current_date)
        ) then suspend;
    end

end^

set term ; ^