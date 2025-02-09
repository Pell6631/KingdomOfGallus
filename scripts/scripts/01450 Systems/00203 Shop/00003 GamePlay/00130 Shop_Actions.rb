module GamePlay
  class Shop
    private

    # Name of the SE to play when an item is bought
    BUY_SE = 'Audio/SE/purchase_sound'

    # Launch the buy sequence
    def launch_buy_sequence
      if data_item(@list_item[@index]).is_limited == false
        buy_unlimited_use_item
      else
        buy_limited_use_item
      end
    end

    # Method describing the process of buying an unlimited use item
    def buy_unlimited_use_item
      price = @list_price[@index].to_s
      item = data_item(@list_item[@index])
      if item.socket == 3 && item.is_a?(Studio::TechItem)
        id_text = 35
        move_name = data_move(Studio::TechItem.from(item).move_db_symbol).name
        ct_num = item.name.gsub(/[^0-9]/, '')
        hash = { NUM3[0] => ct_num, MOVE[1] => move_name, NUM7R => price }
      else
        id_text = 94
        item_name = item.exact_name
        hash = { ITEM2[0] => item_name, NUM7R => price }
      end
      c = display_message(parse_text(11, id_text, hash), 1, text_get(11, 27), text_get(11, 28))
      money_checkout(1) if c == 0
    end

    # Method describing the process of buying an amount of limited use items
    def buy_limited_use_item
      return if amount_selection(@list_price[@index], @list_item[@index])

      return if $game_variables[::Yuki::Var::EnteredNumber] == 0

      quantity = $game_variables[::Yuki::Var::EnteredNumber]
      return if confirm_buy(@list_price[@index], @list_item[@index], quantity)

      money_checkout(quantity)
    end

    # Ask the player if he wants to buy the item
    # @param price [Integer] price of the item
    # @param item_id [Integer] ID of the item
    # @param quantity [Integer] number of item to buy
    # @return [Boolean] if the buy_item procedure should immediately exit
    def confirm_buy(price, item_id, quantity)
      if quantity > 0
        item_str = quantity > 1 ? ext_text(9001, item_id) : data_item(item_id).exact_name
        message = parse_text(11, 25,
                             ITEM2[0] => item_str,
                             NUM2[1] => quantity.to_s,
                             NUM7R => (quantity * price).to_s)
        # Would you like to buy x item for $y ? Yes / No
        c = display_message(message, 1, text_get(11, 27), text_get(11, 28))
        return c != 0
      end
      return true
    end

    # Make the player choose the amount of the item he wants to buy
    # @param price [Integer] price of the item
    # @param item_id [Integer] ID of the item
    # @return [Boolean] if the buy_item procedure should immediately exit
    def amount_selection(price, item_id)
      max_amount = PFM.game_state.money / price
      if (max = Configs.settings.max_bag_item_count) > 0
        max -= $bag.item_quantity(item_id)
        if max <= 0 # Not enough space
          display_message(parse_text(11, 31))
          return true
        end

        max_amount = max if max < max_amount
        if @symbol_or_list.is_a?(Symbol) && @item_quantity[@index] < max_amount
          max_amount = @item_quantity[@index]
        end
      end
      $game_temp.num_input_variable_id = ::Yuki::Var::EnteredNumber
      $game_temp.num_input_digits_max = max_amount.to_s.size
      $game_temp.num_input_start = max_amount
      $game_temp.shop_calling = price
      # How much ?
      display_message(parse_text(11, 23, ITEMPLUR1[0] => determine_article, ITEM2[0] => ext_text(9001, item_id)))
      $game_temp.shop_calling = false
      return false
    end

    VOWELS = %w[A E I O U Y]
    def determine_article
      case $options.language
      when 'fr'
        name = data_item(@list_item[@index]).name
        return name.start_with?(*VOWELS) ? "d'" : 'de '
      else
        return ''
      end
    end

    # Take the good amount of money from the player and some other things
    # @param nb [Integer] the number of items that the player is buying
    def money_checkout(nb)
      display_message(parse_text(11, 29))
      PFM.game_state.lose_money(nb * @list_price[@index])
      update_money_text
      Audio.se_play(BUY_SE)
      $bag.add_item(@list_item[@index], nb)
      @what_was_buyed << @list_item[@index] unless @what_was_buyed.any? { |item| item == @list_item[@index] }
      buy_item_special_offer(nb)
      @shop.remove_from_limited_shop(@symbol_or_list, [@list_item[@index]], [nb]) if @symbol_or_list.is_a?(Symbol)
      update_shop_ui_after_buying(@index)
    end

    # Execute the special offer of the shop when the player bough an item
    # @param quantity [Integer] Number of item bought
    def buy_item_special_offer(quantity)
      if (1..16).include?(@list_item[@index]) && quantity >= 10
        # Honnor ball gift
        display_message(text_get(11, 32))
        $bag.add_item(12, (quantity / 10))
      end
    end

    # Make sure the Shop UI gets updated after buying something
    # @param index [Integer] previous index value
    def update_shop_ui_after_buying(index)
      # Adjust the bag info
      reload_item_list
      unless @force_close 
        @index = index.clamp(0, @last_index)
        @item_list.index = @index
        # Reload the graphics
        update_item_button_list
        update_scrollbar
        update_item_desc
        update_money_text
      end
    end

    # Check the scenario in which the player leaves
    # @return [Integer] the number of the scenario for the player leaving
    def how_do_the_player_leave
      return @what_was_buyed.size.clamp(0, 2)
    end
  end
end
