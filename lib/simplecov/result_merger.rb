#
# Singleton that is responsible for caching, loading and merging
# SimpleCov::Results into a single result for coverage analysis based
# upon multiple test suites.
#
module SimpleCov::ResultMerger
  class << self
    # The path to the .resultset.json cache file
    def resultset_path(command_name)
      File.join(SimpleCov.coverage_path, ".#{command_name}.resultset.json")
    end

    # Loads the cached resultset from YAML and returns it as a Hash
    def resultset(command_name)
      if (stored = stored_data(command_name))
        SimpleCov::JSON.parse(stored)
      else
        {}
      end
    end

    # Returns the contents of the resultset cache as a string or if the file is missing or empty nil
    def stored_data(command_name)
      stored = resultset_path(command_name)
      if File.exist?(stored) and data = File.read(stored) and data.length >= 2
        data
      else
        nil
      end
    end

    def all_results
      Dir.glob(File.join(SimpleCov.coverage_path, ".*.resultset.json")).map { |file|
        File.read(file)
      }.reject { |data|
        data.length < 2
      }.map { |data|
        result = SimpleCov::Result.from_hash(SimpleCov::JSON.parse(data))
        result if ( Time.now - result.created_at ) < SimpleCov.merge_timeout
      }.compact
    end

    #
    # Gets all SimpleCov::Results from cache, merges them and produces a new
    # SimpleCov::Result with merged coverage data and the command_name
    # for the result consisting of a join on all source result's names
    #
    def merged_result
      result_set = all_results
      merge_set = result_set.reduce({}) { |merged, result| result.original_result.merge_resultset(merged) }
      result = SimpleCov::Result.new(merge_set)
      # Specify the command name
      result.command_name = result_set.map(&:command_name).sort.join(", ")
      result
    end

    # Saves the given SimpleCov::Result in the resultset cache
    def store_result(result)
      command_name, data = result.to_hash.first
      new_set = resultset(command_name)
      new_set[command_name] = data
      File.open(resultset_path(command_name), "w+") do |f|
        f.puts SimpleCov::JSON.dump(new_set)
      end
      true
    end

  end
end
