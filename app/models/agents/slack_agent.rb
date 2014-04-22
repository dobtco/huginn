module Agents
  class SlackAgent < Agent

    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The SlackAgent collects any Events sent to it and sends them to a slack webhook URL.
      If the Events' payloads contain a `message`, that will be highlighted, otherwise everything in
      their payloads will be shown.

      Set `channel` to your slack channel, e.g. "#office".

      Set `username` to the desired username for your webhook.

      `icon_url` or `icon_emoji` are optional, and can be used to set the "avatar" for your webhook.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def default_options
      {
        'url' => '',
        'channel' => '',
        'username' => '',
        'icon_url' => '',
        'icon_emoji' => '',
        'expected_receive_period_in_days' => "2"
      }
    end

    def validate_options
      errors.add(:base, "You need to specify a url") unless options['url'].present?
      errors.add(:base, "You need to specify a channel") unless options['channel'].present?
      errors.add(:base, "You need to specify a username") unless options['username'].present?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        send_slack_message(event)
      end
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def send_slack_message(event)
      log "Sending Slack message for event: #{event.id}"


      body = {
        text: event.payload['message'].presence || event.payload.to_s,
        channel: options['channel'],
        username: options['username']
      }

      body[:icon_emoji] = options['icon_emoji'] if options['icon_emoji'].present?
      body[:icon_url] = options['icon_url'] if options['icon_url'].present?

      log "#{options['url']} body: #{body.to_json}"

      HTTParty.post(
        options['url'],
        body: body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end
  end
end
