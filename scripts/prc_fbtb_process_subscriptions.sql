set term ^ ;

create or alter procedure fbtb_process_subscriptions
as
declare subscription_id type of column fbtb_command_subscription.subscription_id;
declare repeat_after type of column fbtb_command_subscription.repeat_after;
declare chat_id type of column fbtb_command_subscription.chat_id;
declare user_id type of column fbtb_command_subscription.user_id;
declare no_sound type of column fbtb_command_subscription.no_sound;

declare command_name type of column fbtb_command.command_name;

declare bot_id type of column fbtb_bot.bot_id;

declare request_id type of column fbtb_command_request.request_id;

declare last_sent timestamp;
declare delay_kind varchar(1);
declare delay_value bigint;
declare sent_after timestamp;

begin
    for select
            cs.subscription_id
            , cs.chat_id
            , cs.user_id
            , cs.repeat_after
            , cs.no_sound
            , c.command_name
            , b.bot_id
            , max(coalesce(cr.result_sent, cr.created)) as last_sent
        from fbtb_command_subscription as cs
            inner join fbtb_command as c using(command_id)
            inner join fbtb_bot as b using(bot_id)
            left join fbtb_command_request as cr using(subscription_id)
        where current_timestamp between
                            coalesce(cs.start_date, current_date) + coalesce(cs.from_time, cast(current_timestamp as time))
                                and coalesce(cs.end_date, current_date) + coalesce(cs.to_time, cast(current_timestamp as time))
            and b.enabled > 0
        group by 1, 2, 3, 4, 5, 6, 7
        into subscription_id, chat_id, user_id, repeat_after, no_sound, command_name, bot_id, last_sent
    do
    begin
        repeat_after = trim(repeat_after);
        delay_kind = right(repeat_after, 1);
        if (delay_kind in ('s', 'm', 'h', 'd', 'w')) then
        begin
            delay_value = substring(repeat_after from 1 for char_length(repeat_after) - 1);
        end
        else
        begin
            delay_kind = null;
            delay_value = repeat_after;
        end
        sent_after = case delay_kind
                        when 'w' then dateadd(:delay_value week to last_sent)
                        when 'd' then dateadd(:delay_value day to last_sent)
                        when 'h' then dateadd(:delay_value hour to last_sent)
                        when 'm' then dateadd(:delay_value minute to last_sent)
                        when 's' then dateadd(:delay_value second to last_sent)
                        else dateadd(:delay_value millisecond to last_sent)
                    end;

        if (current_timestamp >= sent_after) then
        begin
            select request_id
                from fbtb_process_command_request(:bot_id, '/' || :command_name, :chat_id, :user_id, :no_sound, :subscription_id)
                into request_id;
        end

        when any do
        begin
        end
    end
end^

set term ; ^