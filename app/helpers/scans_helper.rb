module ScansHelper

    def prepare_tables_data
        params[:filter_finished] ||= params[:filter_active] ||= 'yours'

        @counts = {
            active: {},
            finished: {}
        }
        %w(yours shared others).each do |type|
            begin
                @counts[:active][type] = scan_filter( type ).
                    light.active.count

                @counts[:active]['total'] ||= 0
                @counts[:active]['total']  += @counts[:active][type]

                @counts[:finished][type] = scan_filter( type ).
                    light.finished.count

                @counts[:finished]['total'] ||= 0
                @counts[:finished]['total']  += @counts[:finished][type]
            rescue
            end

        end

        @active_scans = scan_filter( params[:filter_active] ).active.
            page( params[:active_page] ).
            per( Settings.active_scan_pagination_entries ).order( 'id DESC' )

        @finished_scans = scan_filter( params[:filter_finished] ).finished.light.
            page( params[:finished_page] ).
            per( Settings.finished_scan_pagination_entries ).order( 'id DESC' )

    end

    def scan_filter( filter )
        filter ||= 'yours'

        case filter
            when 'yours'
                current_user.scans.light.where( "owner_id == ?", current_user.id )
            when 'shared'
                current_user.scans.light.where( "owner_id != ?", current_user.id )
            when 'others'
                raise 'Unauthorised!' if !current_user.admin?

                ids = current_user.scans.select( :id ).
                        where( "owner_id != ?", current_user.id ) +
                    current_user.scans.select( :id ).
                        where( "owner_id == ?", current_user.id )

                Scan.where( :id => Scan.select( :id ) - ids )
        end
    end

    def issues_to_graph_data( issues )
        graph_data = {
            severities:       {
                Arachni::Severity::HIGH          => 0,
                Arachni::Severity::MEDIUM        => 0,
                Arachni::Severity::LOW           => 0,
                Arachni::Severity::INFORMATIONAL => 0
            },
            issues:           {},
            elements:         {
                Arachni::Element::FORM   => 0,
                Arachni::Element::LINK   => 0,
                Arachni::Element::COOKIE => 0,
                Arachni::Element::HEADER => 0,
                Arachni::Element::BODY   => 0,
                Arachni::Element::PATH   => 0,
                Arachni::Element::SERVER => 0
            }
        }

        total_severities = 0
        total_elements   = 0

        issues.each.with_index do |issue, i|
            graph_data[:severities][issue.severity] += 1
            total_severities += 1

            graph_data[:issues][issue.name] ||= 0
            graph_data[:issues][issue.name] += 1

            graph_data[:elements][issue.vector_type] += 1
            total_elements += 1
        end

        graph_data
    end

    def issue_severity_to_alert( severity )
        case severity
            when Arachni::Issue::Severity::HIGH
                'important'
            when Arachni::Issue::Severity::MEDIUM
                'warning'
            when Arachni::Issue::Severity::LOW
                'default'
            when Arachni::Issue::Severity::INFORMATIONAL
                'info'
        end
    end

    def response_times_to_alert( time )
        time = time.to_f

        if time >= 0.7
            [ 'alert-error',
              'The server takes too long to respond to the scan requests,' +
                  ' this will severely diminish performance.']
        elsif (0.35..0.7).include?( time )
            [ 'alert-warning',
              'Server response times could be better but nothing to worry about yet.' ]
        else
            [ 'alert-success',
              'Server response times are excellent.' ]
        end
    end

    def concurrent_requests_to_alert( request_count, max )
        max = max.to_i
        request_count = request_count.to_i

        if request_count >= max
            [ 'alert-success',
              'HTTP request concurrency is operating at the allowed maximum.']
        elsif ((max/2)..max).include?( request_count )
            [ 'alert-warning',
              "HTTP request concurrency had to be throttled down (from the " +
                  "maximum of #{max}) due to high server response times, " +
                  'nothing to worry about yet though.' ]
        else
            [ 'alert-error',
              'HTTP request concurrency has been drastically throttled down ' +
                  "(from the maximum of #{max}) due to very high server" +
                  " response times, this will severely decrease performance."]
        end
    end
end
