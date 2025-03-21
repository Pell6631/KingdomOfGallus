module Battle
  module Actions
    # Class describing the usage of switching out a Pokemon
    class Switch < Base
      # Get the Pokemon who's being switched
      # @return [PFM::PokemonBattler]
      attr_reader :who
      # Get the Pokemon with the Pokemon is being switched
      # @return [PFM::PokemonBattler]
      attr_reader :with
      # Create a new switch action
      # @param scene [Battle::Scene]
      # @param who [PFM::PokemonBattler] who's being switched out
      # @param with [PFM::PokemonBattler] with who the Pokemon is being switched
      def initialize(scene, who, with)
        super(scene)
        @who = who
        @with = with
      end

      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return 1 if other.is_a?(HighPriorityItem)
        return 1 if other.is_a?(Attack) && Attack.from(other).pursuit_enabled
        return 1 if other.is_a?(Item)
        return Switch.from(other).who.spd <=> @who.spd if other.is_a?(Switch)

        return -1
      end

      # Execute the action
      def execute
        return if !@who.position || !@who.position.between?(0, $game_temp.vs_type - 1)

        visual = @scene.visual
        # @type [BattleUI::PokemonSprite]
        sprite = visual.battler_sprite(@who.bank, @who.position)
        if @who.alive?
          sprite.go_out
          visual.hide_info_bar(@who)
          switch_out_message unless forced_switch?(who)
          wait_for(sprite, visual)
        end
        # Logically switching the Pokemon
        @scene.logic.switch_battlers(@who, @with)
        @scene.logic.switch_handler.execute_pre_switch_events(@who, @with)
        # Switching the sprite
        sprite.pokemon = @with
        sprite.visible = false # Ensure there's no glitch with animation (the animation sets visible :))
        sprite.go_in
        visual.show_info_bar(@with)
        switch_in_message unless forced_switch?(who)
        wait_for(sprite, visual)
        @scene.logic.switch_handler.execute_switch_events(@who, @with)
        @scene.logic.request_switch(@with, nil) if @with.dead?
        @who.reset_states
      end

      private

      # Wait for the sprite animation to be done
      # @param sprite [#done?]
      # @param visual [Battle::Visual]
      def wait_for(sprite, visual)
        until sprite.done?
          visual.update
          Graphics.update
        end
      end

      # Show the switch out message
      def switch_out_message
        return if @who.dead?

        msg_id = @who.from_party? ? (26 + @who.hp % 5) : 32
        hash = {
          PFM::Text::TRNAME[0] => @scene.battle_info.trainer_name(@who),
          PFM::Text::PKNICK[0] => @who.given_name,
          PFM::Text::PKNICK[1] => @who.given_name
        }
        message = parse_text(18, msg_id, hash)
        @scene.display_message_and_wait(message)
      end

      # Show the switch in message
      def switch_in_message
        msg_id = @with.from_party? ? (22 + @with.hp % 2) : 18
        hash = {
          PFM::Text::TRNAME[0] => @scene.battle_info.trainer_name(@with),
          PFM::Text::PKNICK[0] => @with.given_name,
          PFM::Text::PKNICK[1] => @with.given_name
        }
        message = parse_text(18, msg_id, hash)
        @scene.display_message_and_wait(message)
      end

      # Tell if the Pokemon was forced to switch
      # @param who [PFM::PokemonBattler] the switched out Pokemon
      # @return [Boolean]
      def forced_switch?(who)
        @scene.logic.all_alive_battlers.each do |pokemon|
          pmh = pokemon.move_history
          next if pmh.empty?

          return true if pmh.last.move.force_switch? && pmh.last.targets.include?(who) && pmh.last.current_turn?
        end
        return false
      end
    end
  end
end
