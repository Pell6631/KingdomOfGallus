module PFM
  # The quest management
  #
  # The main object is stored in $quests and PFM.game_state.quests
  class Quests
    # Tell if the system should check the signal when we test finished?(id) or failed?(id)
    AUTO_CHECK_SIGNAL_ON_TEST = true
    # Tell if the system should check the signal when we check the quest termination
    AUTO_CHECK_SIGNAL_ON_ALL_OBJECTIVE_VALIDATED = false
    # The list of active_quests
    # @return [Hash<Integer => Quest>]
    attr_accessor :active_quests
    # The list of finished_quests
    # @return [Hash<Integer => Quest>]
    attr_accessor :finished_quests
    # The list of failed_quests
    # @return [Hash<Integer => Quest>]
    attr_accessor :failed_quests
    # The signals that inform the game what quest started or has been finished
    # @return [Hash<start: Array<Integer>, finish: Array<Integer>, failed: Array<Integer>>]
    attr_accessor :signal
    # Create a new Quest management object
    def initialize
      @active_quests = {}
      @finished_quests = {}
      @failed_quests = {}
      @signal = { start: [], finish: [], failed: [] }
    end

    # Start a new quest if possible
    # @param quest_id [Integer] the ID of the quest in the database
    # @return [Boolean] if the quest started
    def start(quest_id)
      return false if data_quest(quest_id).db_symbol == :__undef__
      return false if finished?(quest_id)
      return false if @active_quests.fetch(quest_id, nil)

      @active_quests[quest_id] = Quest.new(quest_id)
      @signal[:start] << quest_id
      return true
    end

    # Return an active quest by its id
    # @param quest_id [Integer]
    # @return [Quest]
    def active_quest(quest_id)
      return @active_quests[quest_id]
    end

    # Return a finished quest by its id
    # @param quest_id [Integer]
    # @return [Quest]
    def finished_quest(quest_id)
      return @finished_quests[quest_id]
    end

    # Return a failed quest by its id
    # @param quest_id [Integer]
    # @return [Quest]
    def failed_quest(quest_id)
      return @failed_quests[quest_id]
    end

    # Show a goal of a quest
    # @param quest_id [Integer] the ID of the quest in the database
    # @param goal_index [Integer] the index of the goal in the goal order
    def show_goal(quest_id, goal_index)
      return unless (quest = active_quest(quest_id))

      quest.data_set(:goals_visibility, goal_index, true)
    end

    # Tell if a goal is shown or not
    # @param quest_id [Integer] the ID of the quest in the database
    # @param goal_index [Integer] the index of the goal in the goal order
    # @return [Boolean]
    def goal_shown?(quest_id, goal_index)
      return false unless (quest = active_quest(quest_id))

      return quest.data_get(:goals_visibility, goal_index, false)
    end

    # Get the goal data index (if array like items / speak_to return the index of the goal in the array info from
    # data/quest data)
    # @param quest_id [Integer] the ID of the quest in the database
    # @param goal_index [Integer] the index of the goal in the goal order
    # @return [Integer]
    def get_goal_data_index(quest_id, goal_index)
      raise ScriptError, 'This method should be removed!!!!'
      if (quest = @active_quests.fetch(quest_id, nil)).nil?
        if (quest = @finished_quests.fetch(quest_id, nil)).nil?
          return 0 if (quest = @failed_quests.fetch(quest_id, nil)).nil?
        end
      end
      goal_sym = quest[:order][goal_index]
      cnt = 0
      quest[:order].each_with_index do |sym, i|
        break if i >= goal_index
        cnt += 1 if sym == goal_sym
      end
      return cnt
    end

    # Inform the manager that a NPC has been beaten
    # @param quest_id [Integer] the ID of the quest in the database
    # @param npc_name_index [Integer] the index of the name of the NPC in the quest data
    # @return [Boolean] if the quest has been updated
    def beat_npc(quest_id, npc_name_index)
      return false unless (quest = active_quest(quest_id))
      return false unless quest.objective?(:objective_beat_npc, npc_name_index)

      old_count = quest.data_get(:npc_beaten, npc_name_index, 0)
      quest.data_set(:npc_beaten, npc_name_index, old_count + 1)
      check_quest(quest_id)
      return true
    end

    # Inform the manager that a NPC has been spoken to
    # @param quest_id [Integer] the ID of the quest in the database
    # @param npc_name_index [Integer] the index of the name of the NPC in the quest data
    # @return [Boolean] if the quest has been updated
    def speak_to_npc(quest_id, npc_name_index)
      return false unless (quest = active_quest(quest_id))
      return false unless quest.objective?(:objective_speak_to, npc_name_index)

      quest.data_set(:spoken, npc_name_index, true)
      check_quest(quest_id)
      return true
    end

    # Inform the manager that an item has been added to the bag of the Player
    # @param item_id [Integer] ID of the item in the database
    def add_item(item_id)
      item_db_symbol = data_item(item_id).db_symbol
      active_quests.each_value do |quest|
        if quest.objective?(:objective_obtain_item, item_db_symbol)
          old_count = quest.data_get(:obtained_items, item_db_symbol, 0)
          quest.data_set(:obtained_items, item_db_symbol, old_count + 1)
          check_quest(quest.quest_id)
          next
        end
        next unless quest.objective?(:objective_obtain_item, item_id)

        old_count = quest.data_get(:obtained_items, item_id, 0)
        quest.data_set(:obtained_items, item_id, old_count + 1)
        check_quest(quest.quest_id)
      end
    end

    # Inform the manager that a Pokemon has been beaten
    # @param pokemon_symbol [Symbol] db_symbol of the Pokemon in the database
    def beat_pokemon(pokemon_symbol)
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_beat_pokemon, pokemon_symbol)

        old_count = quest.data_get(:pokemon_beaten, pokemon_symbol, 0)
        quest.data_set(:pokemon_beaten, pokemon_symbol, old_count + 1)
        check_quest(quest.quest_id)
      end
    end

    # Inform the manager that a Pokemon has been captured
    # @param pokemon [PFM::Pokemon] the Pokemon captured
    def catch_pokemon(pokemon)
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_catch_pokemon)

        quest_data = data_quest(quest.quest_id)
        quest_data.objectives.each do |objective|
          next unless objective.objective_method_name == :objective_catch_pokemon

          pokemon_id = objective.objective_method_args.first
          next unless quest.objective_catch_pokemon_test(pokemon_id, pokemon)

          pokemon_id = pokemon_id[:id] if pokemon_id.is_a?(Hash)
          old_count = quest.data_get(:pokemon_caught, pokemon_id, 0)
          quest.data_set(:pokemon_caught, pokemon_id, old_count + 1)
          check_quest(quest.quest_id)
        end
      end
    end

    # Inform the manager that a Pokemon has been seen
    # @param pokemon_symbol [Symbol] db_symbol of the Pokemon in the database
    def see_pokemon(pokemon_symbol)
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_see_pokemon, pokemon_symbol)

        quest.data_set(:pokemon_seen, pokemon_symbol, true)
        check_quest(quest.quest_id)
      end
    end

    # Inform the manager an egg has been found
    def egg_found
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_obtain_egg)

        old_count = quest.data_get(:obtained_eggs, 0)
        quest.data_set(:obtained_eggs, old_count + 1)
        check_quest(quest.quest_id)
      end
    end
    alias get_egg egg_found

    # Inform the manager an egg has hatched
    def hatch_egg
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_hatch_egg)

        old_count = quest.data_get(:hatched_eggs, nil, 0)
        quest.data_set(:hatched_eggs, nil, old_count + 1)
        check_quest(quest.quest_id)
      end
    end

    # Check the signals and display them
    def check_up_signal
      return unless $scene.is_a?(Scene_Map)

      if @signal[:start].any?
        start_names = @signal[:start].map { |quest_id| data_quest(quest_id).name }
        show_quest_inform(start_names, true)
      end
      if @signal[:finish].any?
        finish_names = @signal[:finish].collect { |quest_id| data_quest(quest_id).name }
        show_quest_inform(finish_names, false)
        # Switch the quests from stack to stack
        @signal[:finish].each do |quest_id|
          @finished_quests[quest_id] = @active_quests[quest_id] if @active_quests[quest_id]
          @active_quests.delete(quest_id)
        end
      end
      @signal[:start].clear
      @signal[:finish].clear
    end

    # Check if a quest is done or not
    # @param quest_id [Integer] ID of the quest in the database
    def check_quest(quest_id)
      return unless (quest = active_quest(quest_id))
      return if @signal[:finish].include?(quest_id)
      return unless quest.finished?

      @signal[:finish] << quest_id
      check_up_signal if AUTO_CHECK_SIGNAL_ON_ALL_OBJECTIVE_VALIDATED
    end

    # Is a quest finished ?
    # @param quest_id [Integer] ID of the quest in the database
    # @return [Boolean]
    def finished?(quest_id)
      check_up_signal if AUTO_CHECK_SIGNAL_ON_TEST
      return !@finished_quests.fetch(quest_id, nil).nil?
    end

    # Is a quest failed ?
    # @param quest_id [Integer] ID of the quest in the database
    # @return [Boolean]
    def failed?(quest_id)
      check_up_signal if AUTO_CHECK_SIGNAL_ON_TEST
      return !@failed_quests.fetch(quest_id, nil).nil?
    end

    # Get the earnings of a quest
    # @param quest_id [Integer] ID of the quest in the database
    # @return [Boolean] if the earning were givent to the player
    def get_earnings(quest_id)
      return false unless (quest = finished_quest(quest_id))
      return false if quest.data_get(:earnings_distributed, false)

      quest.distribute_earnings
      return true
    end

    # Does the earning of a quest has been taken
    # @param quest_id [Integer] ID of the quest in the database
    def earnings_got?(quest_id)
      check_up_signal if AUTO_CHECK_SIGNAL_ON_TEST
      return false unless (quest = finished_quest(quest_id))

      return quest.data_get(:earnings_distributed, false)
    end

    def import_from_dot24
      mapper = ->((id, quest)) { [id, convert_quest_from_dot24_to_dot25(id, quest)] }
      @active_quests = @active_quests.map(&mapper).to_h
      @finished_quests = @finished_quests.map(&mapper).to_h
      @failed_quests = @failed_quests.map(&mapper).to_h
    end

    def update_quest_data_for_studio
      mapper = ->((id, quest)) { [id, convert_quest_for_studio(id, quest)] }
      @active_quests = @active_quests.map(&mapper).to_h
      @finished_quests = @finished_quests.map(&mapper).to_h
      @failed_quests = @failed_quests.map(&mapper).to_h
    end

    private

    # Convert a quest from .24 to .25
    # @param id [Integer] ID of the quest
    # @param quest [Hash]
    # @return [PFM::Quests::Quest]
    def convert_quest_from_dot24_to_dot25(id, quest)
      return quest if quest.is_a?(PFM::Quests::Quest)

      mapper = ->(v, i) { [i, v] }
      new_quest = PFM::Quests::Quest.new(id)
      objectives = data_quest(id).objectives
      new_quest.data_set(:goals_visibility, quest[:shown])
      new_quest.data_set(:earnings_distributed, quest[:earnings])
      new_quest.data_set(:npc_beaten, quest[:npc_beaten].map.with_index(&mapper).to_h) if quest[:npc_beaten]
      new_quest.data_set(:spoken, quest[:spoken].map.with_index(&mapper).to_h) if quest[:spoken]
      import_data_id_like_objective(objectives, quest, new_quest, :objective_obtain_item, :obtained_items, :items)
      import_data_id_like_objective(objectives, quest, new_quest, :objective_beat_pokemon, :pokemon_beaten, :pokemon_beaten)
      import_data_id_like_objective(objectives, quest, new_quest, :objective_catch_pokemon, :pokemon_caught, :pokemon_catch)
      import_data_id_like_objective(objectives, quest, new_quest, :objective_see_pokemon, :pokemon_seen, :pokemon_seen)
      new_quest.data_set(:obtained_eggs, quest[:egg_counter]) if quest[:egg_counter]
      new_quest.data_set(:hatched_eggs, nil, quest[:egg_hatched]) if quest[:egg_hatched]

      return new_quest
    end

    # Convert a quest for Studio
    # @param id [Integer] ID of the quest
    # @param quest [PFM::Quests::Quest]
    def convert_quest_for_studio(id, quest)
      return false unless quest.is_a?(PFM::Quests::Quest)

      new_quest = quest.clone
      quest_data = new_quest.instance_variable_get(:@data)
      transform_keys_in_hash(quest_data[:obtained_items], :item) if quest_data.key?(:obtained_items)
      transform_keys_in_hash(quest_data[:pokemon_beaten]) if quest_data.key?(:pokemon_beaten)
      transform_keys_in_hash(quest_data[:pokemon_caught]) if quest_data.key?(:pokemon_caught)
      transform_keys_in_hash(quest_data[:pokemon_seen]) if quest_data.key?(:pokemon_seen)
      return new_quest
    end

    # Transform keys in quest data hash
    # @param data [Hash] the data hash to update
    # @param type [Symbol] the objective type (:pokemon, :item)
    def transform_keys_in_hash(data, type = :pokemon)
      a = data.select { |k, _| k.is_a?(Integer) }.transform_keys { |k| type == :pokemon ? data_creature(k).db_symbol : data_item(k).db_symbol }
      data.select! { |k, _| k.is_a?(Symbol) }
      data.merge!(a) { |_, old_v, new_v| old_v + new_v }
    end

    # Import data from ID like objective
    # @param objectives [Array<Studio::Quest::Objective>]
    # @param quest [Hash] old quest
    # @param new_quest [PFM::Quests::Quest] new quest
    # @param test_method_name [Symbol] test method name of the objective
    # @param new_key [Symbol] new symbol key for the objective in new quest
    # @param old_key [Symbol] old symbol key for the objective in old quest
    def import_data_id_like_objective(objectives, quest, new_quest, test_method_name, new_key, old_key)
      return unless quest[old_key]

      objectives = objectives.select { |objective| objective.objective_method_name == test_method_name }
      objectives.each_with_index do |objective, i|
        new_quest.data_set(new_key, objective.objective_method_args.first, quest[old_key][i])
      end
    end

    # Give a specific earning
    # @param earning [Hash]
    def give_earning(earning)
      if earning[:money]
        PFM.game_state.add_money(earning[:money])
      elsif earning[:item]
        $bag.add_item(earning[:item], earning[:item_amount])
      elsif earning[:pokemon]
        pokemon_data = earning[:pokemon]
        PFM.game_state.add_pokemon(pokemon_data.is_a?(Hash) ? PFM::Pokemon.generate_from_hash(pokemon_data) : PFM::Pokemon.new(pokemon_data, 5))
      end
    end

    # Show the new/finished quest info
    # @param names [Array<String>]
    # @param is_new [Boolean]
    def show_quest_inform(names, is_new)
      return unless $scene.is_a?(Scene_Map)

      # @type [Spriteset_Map]
      helper = $scene.spriteset
      names.each { |name| helper.inform_quest(name, is_new) }
    end
  end

  class GameState
    # The player quests informations
    # @return [PFM::Quests]
    attr_accessor :quests
    safe_code('Setup Quest in GameState') do
      on_player_initialize(:quests) { @quests = PFM::Quests.new }
      on_expand_global_variables(:quests) do
        # Variable containing all the quests information
        $quests = @quests
      end
    end
  end
end
