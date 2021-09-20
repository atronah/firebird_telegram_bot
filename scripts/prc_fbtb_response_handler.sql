set term ^ ;

create or alter procedure fbtb_response_handler(
    request_id type of column fbtb_command_request.request_id
    , response type of column fbtb_command_request.result_response
)
as
declare bot_id type of column fbtb_bot.bot_id;

declare request_id type of column fbtb_command_request.request_id;
declare from_chat_id type of column fbtb_command_request.from_chat_id;
declare from_user_id type of column fbtb_command_request.from_user_id;
declare request_text type of column fbtb_command_request.request_text;

declare from_chat_title type of column fbtb_chat.title;
declare from_user_name type of column fbtb_user.username;

declare command_name type of column fbtb_command.command_name;

declare message_data blob sub_type text;
declare pos bigint;
-- Constants
-- -- status of command request
declare UNPROCESSED type of column fbtb_command_request.status = 0;
declare PREPARED type of column fbtb_command_request.status = 1;
declare SENT type of column fbtb_command_request.status = 2;
declare SKIPPED type of column fbtb_command_request.status = 3;
declare FAILED type of column fbtb_command_request.status = 4;
begin
    -- processing sendMessages responses:
    if (request_id > 0) then
    begin
        update fbtb_command_request
                set status = :SENT
                    , status_updated = 'now'
                    , result_response = :response
            where request_id = :request_id;
    end
    -- processing getUpdates responses:
    else if (request_id < 0) then
    begin
        bot_id = -request_id;

        for select
                val as message_data
            from aux_json_parse(:request_text) as j
            where j.path = '/-/result/-/'
                and j.name = 'message'
            into message_data
        do
        begin
            from_chat_id = null; from_chat_title = null;
            from_user_id = null; from_user_name = null;
            request_text = null;
            select
                    max(iif(path = '/-/chat/' and name = 'id', val, null)) as from_chat_id
                    , max(iif(path = '/-/chat/' and name = 'title', val, null)) as from_chat_title
                    , max(iif(path = '/-/from/' and name = 'id', val, null)) as from_user_id
                    , max(iif(path = '/-/from/' and name = 'username', val, null)) as from_user_name
                    , max(iif(path = '/-/' and name = 'text', val, null)) as request_text
                from aux_json_parse(:message_data)
                into from_chat_id, from_chat_title
                        , from_user_id, from_user_name
                        , request_text;

            select request_id
                from fbtb_process_command_request(:bot_id, :request_text, :from_chat_id, :from_user_id)
                into request_id;

            update or insert into fbtb_chat(chat_id, title, updated) value(:from_chat_id, :from_chat_title, 'now');
            update or insert into fbtb_user(user_id, username, updated) value(:from_user_id, :from_user_name, 'now');
        end
    end
end^

set term ; ^