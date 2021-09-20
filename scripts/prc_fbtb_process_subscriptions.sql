set term ^ ;

create or alter procedure fbtb_process_subscriptions
as
declare chat_id type of column fbtb_command_subscription.chat_id;
declare user_id type of column fbtb_command_subscription.user_id;

declare last_sent timestamp;
declare repeat_after type of column fbtb_command_subscription.repeat_after;
declare delay_kind varchar(1);
declare delay_value bigint;
declare sent_after timestamp;

declare no_sound type of column fbtb_command_subscription.no_sound;
begin
    for select
            s.subscription_id
            , s.chat_id
            , s.user_id
            , s.repeat_after
            , s.no_sound
            , c.command_name
            , b.bot_id
            , max(coalesce(cr.sent, cr.created)) as last_sent
        from fbtb_command_subscription a cs
            inner join fbtb_command as c using(command_id)
            inner join fbtb_bot as b using(bot_id)
            left join fbtb_process_command_request as cr on using(subscription_id)
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
                        when 'w' then dateadd(:delay_value weekend to last_sent)
                        when 'd' then dateadd(:delay_value day to last_sent)
                        when 'h' then dateadd(:delay_value hour to last_sent)
                        when 'm' then dateadd(:delay_value minute to last_sent)
                        when 's' then dateadd(:delay_value second to last_sent)
                        else dateadd(:delay_value millisecond to last_sent)
                    end;

        if (current_timestamp >= sent_after) then
        begin
            select command_id
                from fbtb_process_command_request(:bot_id, '/' || command_name, :chat_id, :user_id, :no_sound, :subscription_id)
                into command_id;
        end

        when any do
        begin
        end
    end
end^

set term ; ^