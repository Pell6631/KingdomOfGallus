module UI
  module Quest
    class RewardScreen < SpriteStack
      REWARD_COORDINATE = [
        [3, 1],
        [137, 1],
        [3, 36],
        [137, 36]
      ]
      # Initialize the RewardScreen component
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      def initialize(viewport, x, y)
        super(viewport, x, y)
        @quest = nil
        @index_display = 0
        create_prize_back
      end

      # Scroll the rewards if there's more than 4 rewards
      # @param direction [Symbol] :left of :right
      def scroll_rewards(direction)
        return if quest_data.earnings.size < 5

        @index_display += (direction == :left ? -1 : 1)
        @index_display = 0 if @index_display > quest_data.earnings.size / 4
        @index_display = quest_data.earnings.size / 4 if @index_display < 0
        regenerate_rewards(true)
      end

      # Reload all sub-component with a new quest
      # @param quest [PFM::Quests::Quest]
      def quest=(quest)
        @quest = quest
        @index_display = 0
        regenerate_rewards
      end

      private

      def create_prize_back
        @prize_back = add_sprite(0, 0, 'quest/prize_back')
      end

      def create_rewards
        coord = REWARD_COORDINATE
        @rewards = []
        4.times do |i|
          @rewards << push_sprite(RewardButton.new(viewport, x + coord[i][0], y + coord[i][1], quest_data.earnings[i + (@index_display * 4)]))
        end
      end

      # Regeneration procedure of the rewards
      # @param bool [Boolean] if RewardScreen should be visible afterward
      def regenerate_rewards(bool = false)
        @rewards.each(&:dispose) unless @rewards.nil?

        create_rewards
        self.visible = bool
      end

      # Return the data for the current quest stocked
      # @return [Studio::Quest]
      def quest_data
        return data_quest(@quest.quest_id)
      end
    end

    class RewardButton < SpriteStack
      # Create the RewardButton
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      # @param reward [Studio::Quest::Earning, nil]
      def initialize(viewport, x, y, reward)
        super(viewport, x, y)
        @viewport = viewport
        @reward = reward
        create_frame
        if @reward
          determine_reward
          create_icon
          create_reward_name
          create_reward_quantity
        end
      end

      private

      def create_frame
        @frame = add_sprite(0, 0, 'quest/prize_button')
      end

      # Determine the reward and set the right text and icons
      def determine_reward
        hash = send(@reward.earning_method_name)
        @icon_type = hash[:type]
        @reward_id = hash[:id]
        @reward_name = hash[:name]
        @reward_quantity = hash[:quantity]
      end

      def create_icon
        if @icon_type == UI::PokemonIconSprite
          @icon = add_sprite(1, 1, NO_INITIAL_IMAGE, false, type: @icon_type)
          pokemon = PFM::Pokemon.new(@reward_id, 1)
          pokemon.egg_init if @reward.earning_method_name == :earning_egg
          @icon.data = pokemon
        else
          @icon = add_sprite(1, 1, NO_INITIAL_IMAGE, type: @icon_type)
          @icon.data = @reward_id
        end
      end

      def create_reward_name
        @reward_name = add_text(34, 17, 92, 10, @reward_name, color: 24)
      end

      def create_reward_quantity
        @reward_quantity = add_text(35, 3, 92, 10, "x#{@reward_quantity}", color: 10)
      end

      # Hash defining how the reward should be created if it's money
      # @return [Hash]
      def earning_money
        return {
          type: UI::ItemSprite,
          id: 223,
          name: 'Money',
          quantity: @reward.earning_args[0]
        }
      end

      # Hash defining how the reward should be created if it's an item
      # @return [Hash]
      def earning_item
        return {
          type: UI::ItemSprite,
          id: @reward.earning_args[0],
          name: data_item(@reward.earning_args[0]).name,
          quantity: @reward.earning_args[1]
        }
      end

      # Hash defining how the reward should be created if it's a Pokemon
      # @return [Hash]
      def earning_pokemon
        data = @reward.earning_args[0]
        pokemon_id = data.is_a?(Hash) ? data[:id] : data
        return {
          type: UI::PokemonIconSprite,
          id: pokemon_id,
          name: data_creature(pokemon_id).name,
          quantity: 1
        }
      end

      # Hash defining how the reward should be created if it's a egg
      # @return [Hash]
      def earning_egg
        data = @reward.earning_args[0]
        pokemon_id = data.is_a?(Hash) ? data[:id] : data
        return {
          type: UI::PokemonIconSprite,
          id: pokemon_id,
          name: text_file_get(0)[0],
          quantity: 1
        }
      end
    end
  end
end
