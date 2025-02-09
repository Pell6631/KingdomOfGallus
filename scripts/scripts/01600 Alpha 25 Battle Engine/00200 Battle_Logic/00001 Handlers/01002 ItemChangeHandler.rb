module Battle
  class Logic
    # Handler responsive of answering properly item changes requests
    class ItemChangeHandler < ChangeHandlerBase
      include Hooks

      # List of item that cannot be knocked off
      PROTECTED_ITEMS = %i[exp_share lucky_egg amulet_coin oak_s_letter gram_1 gram_2 gram_3 prof_s_letter letter
                           greet_mail favored_mail rsvp_mail thanks_mail inquiry_mail like_mail reply_mail
                           bridge_mail_s bridge_mail_d bridge_mail_t bridge_mail_v bridge_mail_m]
      # TO DO : Add Z-Crystals to PROTECTED_ITEMS (7G)
      # List of items that cannot be knocked off if the holder is a specific Pokemon
      PROTECTED_POKEMON_ITEMS = {
        giratina: %i[griseous_orb],
        arceus: %i[flame_plate splash_plate zap_plate meadow_plate icicle_plate fist_plate toxic_plate earth_plate sky_plate mind_plate insect_plate
                   stone_plate spooky_plate draco_plate dread_plate iron_plate pixie_plate],
        genesect: %i[shock_drive burn_drive chill_drive douse_drive],
        silvally: %i[ bug_memory dark_memory dragon_memory electry_memory fairy_memory fighting_memory fire_memory flying_memory ghost_memory
                      grass_memory ground_memory ice_memory poison_memory psychic_memory rock_memory steel_memory water_memory],
        kyogre: %i[blue_orb],
        groudon: %i[red_orb],
        zacian: %i[rusted_sword],
        zamazenta: %i[rusted_shield],

        venusaur: %i[venusaurite], charizard: %i[charizardite_x charizardite_y], blatoise: %i[blastoisinite],
        alakazam: %i[alakazite], gengar: %i[gengarite], kangaskhan: %i[kangaskhanite], pinsir: %i[pinsirite],
        gyarados: %i[gyaradosite], aerodactyl: %i[aerodactylite], mewtwo: %i[mewtwonite_x mewtwonite_y],
        ampharos: %i[ampharosite], scizor: %i[scizorite], heracross: %i[heracronite], houndoom: %i[houndoominite],
        tyranitar: %i[tyranitarite], blaziken: %i[blazikenite], gardevoir: %i[gardevoirite], mawile: %i[mawilite],
        aggron: %i[aggronite], medicham: %i[medichamite], manectric: %i[manectite], banette: %i[banettite],
        absol: %i[absolite], latias: %i[latiasite], latios: %i[latiosite], garchomp: %i[garchompite],
        lucario: %i[lucarionite], abomasnow: %i[abomasite], beedril: %i[beedrillite], pidgeot: %i[pidgeotite],
        slowbro: %i[slowbronite], steelix: %i[steelixite], sceptile: %i[sceptilite], swamper: %i[swampertite],
        sableye: %i[sablenite], sharpedo: %i[sharpedoite], camerupt: %i[cameruptite], altaria: %i[altarianite],
        glalie: %i[glalitite], salamence: %i[salamencite], metagross: %i[metagrossite], lopunny: %i[lopunnite],
      }

      # Function that change the item held by a Pokemon
      # @param db_symbol [Symbol, :none] Symbol ID of the item
      # @param overwrite [Boolean] if the actual item held should be overwritten
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @return [Boolean] if the operation was successfull
      def change_item(db_symbol, overwrite, target, launcher = nil, skill = nil)
        log_data("# change_item(#{db_symbol}, #{overwrite}, #{target}, #{launcher}, #{skill})")
        exec_hooks(ItemChangeHandler, :pre_item_change, binding)
        target.battle_item = db_symbol == :none ? 0 : data_item(db_symbol).id
        target.item_holding = target.battle_item if overwrite
        exec_hooks(ItemChangeHandler, :post_item_change, binding)
        return true
      rescue Hooks::ForceReturn => e
        log_data("# FR: change_item #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end

      # Function that checks if the Pokemon can lose its item
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @return [Boolean]
      def can_lose_item?(target, launcher = nil)
        return false unless target.hold_item?(target.item_db_symbol)
        return false if %i[none __undef__].include?(target.battle_item_db_symbol) || PROTECTED_ITEMS.include?(target.item_db_symbol)
        return false if target.dead?
        return false if launcher&.can_be_lowered_or_canceled?(target.has_ability?(:sticky_hold))
        return false if PROTECTED_POKEMON_ITEMS[target.db_symbol]&.include?(target.battle_item_db_symbol)
        return false if target.effects.has?(:substitute) && target != launcher

        return true
      end

      # Function that checks if the Pokemon can give its item to a target
      # @param giver [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @return [Boolean]
      def can_give_item?(giver, target, launcher = giver)
        return false unless can_lose_item?(giver, launcher)
        return false if target.hold_item?(target.item_db_symbol)
        return false if target.battle_item_db_symbol == :__undef__
        return false if PROTECTED_POKEMON_ITEMS.keys.include?(target.db_symbol)

        return true
      end

      class << self
        # Function that registers a pre_item_change hook
        # @param reason [String] reason of the pre_item_change registration
        # @yieldparam handler [ItemChangeHandler]
        # @yieldparam db_symbol [Symbol] Symbol ID of the item
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [:prevent, nil] :prevent if the item change cannot be applied
        def register_pre_item_change_hook(reason)
          Hooks.register(ItemChangeHandler, :pre_item_change, reason) do |hook_binding|
            result = yield(
              self,
              hook_binding.local_variable_get(:db_symbol),
              hook_binding.local_variable_get(:target),
              hook_binding.local_variable_get(:launcher),
              hook_binding.local_variable_get(:skill)
            )
            force_return(false) if result == :prevent
          end
        end

        # Function that registers a post_item_change hook
        # @param reason [String] reason of the post_item_change registration
        # @yieldparam handler [ItemChangeHandler]
        # @yieldparam db_symbol [Symbol] Symbol ID of the item
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        def register_post_item_change_hook(reason)
          Hooks.register(ItemChangeHandler, :post_item_change, reason) do |hook_binding|
            yield(
              self,
              hook_binding.local_variable_get(:db_symbol),
              hook_binding.local_variable_get(:target),
              hook_binding.local_variable_get(:launcher),
              hook_binding.local_variable_get(:skill)
            )
          end
        end
      end
    end

    # Register the consumed item (Harvest & Recycle)
    ItemChangeHandler.register_pre_item_change_hook('PSDK item change pre: Consumed item') do |_, db_symbol, target|
      next if target.item_consumed || target.effects.has?(:item_stolen)
      next unless db_symbol == :none

      target.item_consumed = true
      target.consumed_item = target.battle_item_db_symbol
    end

    # Retrieve the consumed item
    ItemChangeHandler.register_pre_item_change_hook('PSDK item change pre: Retrieve item') do |_, db_symbol, target|
      next if db_symbol == :none || data_item(db_symbol).db_symbol == :__undef__

      target.item_consumed = false
      target.consumed_item = nil
    end

    # Register effects
    ItemChangeHandler.register_post_item_change_hook('PSDK item change post: Effects') do |handler, db_symbol, target, launcher, skill|
      handler.logic.each_effects(target, launcher) do |effect|
        next effect.on_post_item_change(handler, db_symbol, target, launcher, skill)
      end
    end
    ItemChangeHandler.register_pre_item_change_hook('PSDK item change pre: Effects') do |handler, db_symbol, target, launcher, skill|
      handler.logic.each_effects(target, launcher) do |effect|
        next effect.on_pre_item_change(handler, db_symbol, target, launcher, skill)
      end
    end
  end
end
