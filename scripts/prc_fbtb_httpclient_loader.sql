set term ^ ;

create or alter procedure fbtb_httpclient_loader
returns(
    logid bigint
    , logmode smallint
    , msgid type of column mds_tlgn_message.message_id
    , msgtext type of column mds_tlgn_message.message_text
    , uri type of column mds_tlgn_message.url
    , method type of column mds_tlgn_message.http_method
    , action varchar(32)
)
as
-- Constants
-- -- EXCHANGELOG.LOGMODE
declare SYNC_MODE smallint = 0;
declare ASYNC_MODE smallint = 1;
begin
    logmode = :SYNC_MODE;

    for select
            request_id as logid
            , request_id as msgid
            , result_text as msgtext
            , url as uri
            , http_method as method
        from fbtb_get_requests as m
        where m.sent is null
            and current_timestamp between
                coalesce(t.start_date, current_date) + coalesce(t.start_time, cast(current_timestamp as time))
                and coalesce(t.end_date, current_date) + coalesce(t.end_time, cast(current_timestamp as time))
            into logid, msgid, msgtext, uri, method
    do
    begin
        suspend;
    end
end^

set term ; ^