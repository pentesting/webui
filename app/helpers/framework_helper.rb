=begin
    Copyright 2013 Tasos Laskos <tasos.laskos@gmail.com>

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
=end

module FrameworkHelper

    def framework( opts = Arachni::Options.instance, &block )
        fail 'This method requires a block.' if !block_given?
        f = Arachni::Framework.new( opts )
        begin
            block.call f
        ensure
            f.reset
        end
    end

    def modules
        components_for( :modules )
    end

    def plugins
        components_for( :plugins )
    end

    def default_plugins
        components_for( :plugins, :default )
    end

    def reports
        components_for( :reports )
    end

    def reports_with_outfile
        h = {}
        reports.
            reject { |_, info| !info[:options] || !info[:options].map { |o| o.name  }.include?( 'outfile' ) }.
            map { |name, info| h[name] = info[:name] }
        h
    end

    def components_for( type, list = :available )
        path = File.join( Rails.root, 'config', 'component_cache', "#{type}_#{list}.yml" )

        if !File.exists?( path )
            components = framework do |f|
                (manager = f.send( type )).send( list ).inject( {} ) do |h, name|
                    h[name] = manager[name].info.merge( path: manager.name_to_path( name ) )
                    h[name][:author] = [ h[name][:author] ].flatten
                    h[name][:authors] = h[name][:author]
                    h
                end
            end

            File.open( path, 'w' ) do |f|
                f.write components.to_yaml
            end
        end

        YAML.load( IO.read( path ) )
    end

    extend self
end
