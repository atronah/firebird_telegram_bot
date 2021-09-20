set term ^ ;

create or alter procedure fbtb_httpclient_handler(
    logid bigint
    , fromgrpid bigint
    , dbpassword varchar(64) = ''
    , request blob sub_type text = null
)
returns(
    response blob sub_type text
    , msgid type of column mds_tlgn_message.message_id
)
as
begin
    msgid = logid;
    execute procedure fbtb_response_handler(:logid, :fbtb_response_handler);

    suspend;
end^

set term ; ^