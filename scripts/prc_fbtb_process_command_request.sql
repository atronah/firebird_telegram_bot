set term ^ ;

create or alter procedure fbtb_process_command_request(
    bot_id type of column fbtb_bot.bot_id
    , request_text type of column fbtb_command_request.request_text
    , from_chat_id type of column fbtb_command_request.from_chat_id
    , from_user_id type of column fbtb_command_request.from_user_id
    , no_sound type of column fbtb_command_subscription.no_sound = null
    , subscription_id type of column fbtb_command_subscription.subscription_id = null
)
returns (
    request_id type of column fbtb_command_request.request_id
    , command_id type of column fbtb_command_request.command_id
    , command_name type of column fbtb_command.command_name
    , command_arguments type of column fbtb_command_request.command_arguments
    , result_statement type of column fbtb_command_request.result_statement
    , result_text type of column fbtb_command_request.result_text
    , url type of column fbtb_command_request.url
    , http_method type of column fbtb_command_request.http_method
    , status type of column fbtb_command_request.status
    , status_info type of column fbtb_command_request.status_info
)
as
declare allowed_chat_id_list type of column fbtb_command.allowed_chat_id_list;
declare allowed_user_id_list type of column fbtb_command.allowed_user_id_list;

declare repeat_after type of column fbtb_command_subscription.repeat_after;
declare start_date type of column fbtb_command_subscription.start_date;
declare end_date type of column fbtb_command_subscription.end_date;
declare from_time type of column fbtb_command_subscription.from_time;
declare to_time type of column fbtb_command_subscription.to_time;

declare data_db type of column fbtb_bot.data_db;
declare data_user type of column fbtb_bot.data_user;
declare data_password type of column fbtb_bot.data_password;

declare pos bigint;

-- Constants
-- -- status of command request
declare UNPROCESSED type of column fbtb_command_request.status = 0;
declare PREPARED type of column fbtb_command_request.status = 1;
declare SENT type of column fbtb_command_request.status = 2;
declare SKIPPED type of column fbtb_command_request.status = 3;
declare FAILED type of column fbtb_command_request.status = 4;
-- -- other
declare ENDL varchar(2) = '
';
begin
    if (bot_id is null
        or from_chat_id is null
        or from_user_id is null
        or request_text not starts with '/'
        ) then exit;

    pos = position(' ' in request_text);

    command_arguments = iif(pos > 0, substring(request_text from pos + 1), null);
    command_name = iif(pos > 0
                        , substring(request_text from 2 for pos - 2)
                        , substring(request_text from 2));

    -- in group chats commands for bot should countain bot name after `@` symbol (`/command@my_bot`)
    if ('@' in command_name)
        then command_name = substring(command_name from 1 for position('@') - 1);

    http_method = 'POST';

    status = PREPARED;
    no_sound = coalesce(no_sound, 0);

    if (command_name = 'help') then
    begin
        command_id = -1;

        result_text = 'Common commands:' || :ENDL
            || '- `/help` - shows that message' || :ENDL
            || '- `/subscribe COMMAND REPEAT_AFTER [START_DATE] [END_DATE] [FROM_TIME] [TO_TIME] [NO_SOUND]`'
                || ' - Adds subscription to the command `COMMAND`'
                || ' for the chat where the `/subscribe` was execute.'
                || ' Subscription means that in period from `START_DATE` to `END_DATE`'
                || ' the `COMMAND` will being executed automatically'
                || ' between `FROM_TIME` and `TO_TIME` with delay'' `REPEAT_AFTER`'
                || ' and result will being send to the current chat'
                || ' (without notification if `NO_SOUND` > 0).' || :ENDL
            || '- `/unsubscribe COMMAND` - stop subscription for ' || :ENDL
            || coalesce(:ENDL
                        || 'Database commands:' || :ENDL
                        || (select
                                 list('- /' || coalesce(c.command_name, 'null')
                                        || coalesce(' - ' || c.command_description, '')
                                        , :ENDL)
                            from fbtb_command as c
                            where c.bot_id = :bot_id
                                and (coalesce(c.allowed_chat_id_list, '') = ''
                                        or ',' || c.allowed_chat_id_list || ','
                                                like '%,' || :from_chat_id || ',%'
                                )
                                and (coalesce(c.allowed_user_id_list, '') = ''
                                        or ',' || c.allowed_user_id_list || ','
                                                like '%,' || :from_user_id || ',%'
                                )
                            )
                        , '');
    end
    else if (command_name = 'subscribe') then
    begin
        result_text = null;
        begin
            select
                    max(iif(idx = 1, part, null)) as command_name
                    , max(iif(idx = 2, part, null)) as repeat_after
                    , max(iif(idx = 3, part, null)) as start_date
                    , max(iif(idx = 4, part, null)) as end_date
                    , max(iif(idx = 5, part, null)) as from_time
                    , max(iif(idx = 6, part, null)) as to_time
                    , max(iif(idx = 7, part, null)) as no_sound
                from aux_split_text(:command_arguments, ' ')
                into command_name, repeat_after, start_date, end_date, from_time, to_time, no_sound;
            when any do
            begin
                result_text = 'Incorrect usage';
            end
        end

        if (request_text is null and command_name is null)
            then request_text = 'COMMAND is required';

        if (request_text is null and repeat_after NOT similar to '[0-9]+(s|m|h|d|w)?')
            then request_text = 'REPEAT_AFTER format is incorrect';

        if (request_text is null) then
        begin
            command_id = null; allowed_chat_id_list = null; allowed_user_id_list = null;
            select command_id
                    , allowed_chat_id_list
                    , allowed_user_id_list
                from fbtb_command as c
                where c.bot_id = :bot_id
                    and c.command_name = :command_name
                into command_id, allowed_chat_id_list, allowed_user_id_list;

            if (command_id is null)
                then result_text = 'Command `' || coalesce(:command_name, 'null')
                                    || '` not supported by the bot';
            else if (coalesce(:allowed_chat_id_list, '') > ''
                        and ',' || :allowed_chat_id_list || ','
                            NOT like '%,' || :from_chat_id || ',%')
                then result_text = 'Command `' || coalesce(:command_name, 'null')
                                    || '` not allowed for this chat (chat_id='
                                        || coalesce(from_chat_id, 'null') || ')';
            else if (coalesce(:allowed_user_id_list, '') > ''
                        and ',' || :allowed_user_id_list || ','
                            NOT like '%,' || :from_user_id || ',%')
                then result_text = 'Command `' || coalesce(:command_name, 'null')
                                    || '` not allowed for user with id='
                                    || coalesce(from_user_id, 'null');
            else
            begin
                subscription_id = (select cs.subscription_id
                                    from fbtb_command_subscription as cs
                                    where cs.command_id = :command_id
                                        and chat_id = :from_chat_id
                                        and user_id = :from_user_id);
                if (subscription_id is null)
                    then subscription_id = next value for fbtb_command_subscription_seq;
                update or insert into fbtb_command_subscription
                            (subscription_id
                            , command_id, chat_id, user_id
                            , repeat_after, start_date, end_date, from_time, to_time
                            , no_sound)
                    values (:subscription_id
                            , :command_id, :from_chat_id, :from_user_id
                            , :repeat_after, :start_date, :end_date, :from_time, :to_time
                            , :no_sound);
            end
        end

        command_id = -2;
        command_name = 'subscribe';
    end
    else if (command_name = 'unsubscribe') then
    begin
        select command_id
                from fbtb_command as c
                where c.bot_id = :bot_id
                    and c.command_name = :command_name
                into command_id;
        subscription_id = null;

        select
                cs.subscription_id
                , 'Subscription to `/' || :command_name || '` '
                    || ' has been removed.' || :ENDL || :ENDL
                    || 'To re-subscribe send:' || :ENDL
                    || '`/subscribe '
                            || :command_name
                            || ' ' || cs.repeat_after
                            || coalesce(' ' || cs.start_date, '')
                            || coalesce(' ' || cs.end_date, '')
                            || coalesce(' ' || cs.from_time, '')
                            || coalesce(' ' || cs.to_time, '')
                            || coalesce(' ' || cs.no_sound, '')
                    || '`'
            from fbtb_command_subscription as cs
            where cs.command_id = :command_id
                and chat_id = :from_chat_id
                and user_id = :from_user_id
            into subscription_id, result_text;


        if (subscription_id is null) then
        begin
            result_text = 'Subscription to `/' || :command_name
                            || '` for chat ' || coalesce(:from_chat_id, 'null')
                            || ' and user ' || coalesce(:from_user_id, 'null')
                            || ' not found';
        end
        else delete from fbtb_command_subscription
                where subscription_id = :subscription_id;
    end
    else
    begin
        -- for processing subscription skipps by default until check all errors
        if (subscription_id is not null)
            then status = SKIPPED;

        command_id = null; allowed_chat_id_list = null; allowed_user_id_list = null;
        select command_id
                , allowed_chat_id_list
                , allowed_user_id_list
                , result_statement
            from fbtb_command as c
            where c.bot_id = :bot_id
                and c.command_name = :command_name
            into command_id, allowed_chat_id_list, allowed_user_id_list, result_statement;

        if (command_id is null)
            then result_text = 'Command `' || coalesce(:command_name, 'null')
                                || '` not supported by the bot';
        else if (coalesce(:allowed_chat_id_list, '') > ''
                    and ',' || :allowed_chat_id_list || ','
                        NOT like '%,' || :from_chat_id || ',%')
            then result_text = 'Command `' || coalesce(:command_name, 'null')
                                || '` not allowed for this chat (chat_id='
                                    || coalesce(from_chat_id, 'null') || ')';
        else if (coalesce(:allowed_user_id_list, '') > ''
                    and ',' || :allowed_user_id_list || ','
                        NOT like '%,' || :from_user_id || ',%')
            then result_text = 'Command `' || coalesce(:command_name, 'null')
                                || '` not allowed for user with id='
                                || coalesce(from_user_id, 'null');
        else if (coalesce(result_statement, '') = '')
            then result_text = 'Empty SQL-statement for the command `'
                                || coalesce(:command_name, 'null')|| '`';
        else
        begin
            select
                    b.data_db, b.data_user, b.data_password
                from fbtb_bot as b
                where b.bot_id = :bot_id
                into data_db, data_user, data_password;

            if (coalesce(data_db, '') = ''
                or coalesce(data_user, '') = ''
                or coalesce(data_password, '') = ''
            ) then result_text = 'Database conection settings wasn''t specified for the bot';

            if (result_text is null) then
            begin
                status = PREPARED; -- mark to send for subscription if no errors

                execute statement result_statement
                    on external :data_db as user :data_user password :data_password
                    into result_text;
                when any do
                begin
                    result_text = result_statement;
                end
            end

        end
    end


    url = 'https://api.telegram.org/bot'|| (select bot_token from fbtb_bot where bot_id = :bot_id)
            || '/sendMessage?chat_id='|| from_chat_id
            || iif(coalesce(no_sound, 0) > 0, '&disable_notification=true', '');

    request_id = next value for fbtb_command_request_seq;
    insert into fbtb_command_request
                (request_id, from_chat_id, from_user_id
                , command_id, command_arguments, request_text
                , result_statement, result_text
                , url, http_method
                , status, status_info, status_updated
                , subscription_id)
        values(:request_id, :from_chat_id, :from_user_id
                , :command_id, :command_arguments, :request_text
                , :result_statement, :result_text
                , :url, :http_method
                , :status, :status_info, 'now'
                , :subscription_id);
    suspend;
end^

set term ; ^