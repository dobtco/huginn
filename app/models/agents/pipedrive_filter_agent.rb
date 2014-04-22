module Agents
  class PipedriveFilterAgent < Agent

    cannot_be_scheduled!

    description <<-MD
      The PipedriveFilterAgent looks at all of our pipedrive events, and determines which ones are
      worth listening to.

      Currently we listen for when:

        - a deal is created
        - a deal changes status
    MD

    event_description <<-MD
      For each event that we care about, we'll output an event with a humanized
      message from the event JSON string.

      {
        'message' => 'Sid Burgess created a new deal ...'
      }
    MD

    def default_options
      {
        'expected_update_period_in_days' => "1"
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def validate_options
      unless %w[expected_update_period_in_days].all? { |field| options[field].present? }
        errors.add(:base, "All fields are required")
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        log "Receiving pipedrive event: #{event.id}"
        check_for_deal_added(event)
        check_for_deal_changed_stage(event)
      end
    end

    def get_stage_name(stage_id)
      Pipedrive::Stage.find(stage_id).try(:name) || 'Unknown stage'
    end

    def check_for_deal_changed_stage(event)
      return unless (event.payload['event'] == 'updated.deal') &&
                    (event.payload['previous']['stage_id'] != event.payload['current']['stage_id'])

      create_event payload: {
        message: "User moved #{event.payload['current']['title']} from
                 #{get_stage_name(event.payload['previous']['stage_id'])} to
                 #{get_stage_name(event.payload['current']['stage_id'])}.".squish
      }
    end

    def check_for_deal_added(event)
      return unless event.payload['event'] == 'added.deal'

      create_event payload: {
        message: "User created #{event.payload['current']['title']} in
                 #{get_stage_name(event.payload['current']['stage_id'])}.".squish
      }
    end

  end
end

