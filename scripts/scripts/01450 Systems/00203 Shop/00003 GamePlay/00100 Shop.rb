module GamePlay
  class Shop < BaseCleanUpdate::FrameBalanced
    # Create a new Item Shop
    # @overload initialize(symbol_shop)
    #   @param symbol_shop [Symbol] the symbol of the shop to open
    # @overload initialize(symbol_shop, price_overwritten)
    #   @param symbol_shop [Symbol] the symbol of the shop to open
    #   @param price_overwrite [Hash] the hash containing the new price (value) of an item id (key)
    # @overload initialize(list_id_object)
    #   @param list_id_object [Array<Symbol>] the array containing the id of the items to sell
    # @overload initialize(list_id_object, price_overwrite)
    #   @param list_id_object [Array<Symbol>] the array containing the id of the items to sell
    #   @param price_overwrite [Hash] the hash containing the new price (value) of an id (key)
    # @example Opening an already defined shop with limited items
    #   GamePlay::Shop.new(:shop_pewter_city) # Will open the Shop with symbol :shop_pewter_city (the shop must be already defined beforehand)
    # @example Opening an already defined shop with limited items but with temporarily overwritten price
    #   GamePlay::Shop.new(:shop_pewter_city, {17: 300, 25: 3000}) # Will open the Shop with symbol :shop_pewter_city while overwritting the price for items with ID 17 or 25
    # @example Opening a simple unlimited shop with items, using their original prices
    #   GamePlay::Shop.new([1, 2, 3, 4]) # Will open a Shop selling Master balls, Ultra Balls, Great Balls and Poké Balls at their original price
    # @example Opening a simple unlimited shop with items while overwritting temporarily the original price
    #   GamePlay::Shop.new([4, 17], {4: 100, 17: 125}) # Will open a Shop selling Poké Balls at 100 Pokédollars and Potions at 125 Pokédollars
    def initialize(symbol_or_list, price_overwrite = {}, show_background: true)
      super()
      return if symbol_or_list == false
      @force_close = nil
      @shop = PFM.game_state.shop
      @show_background = :show_background
      @symbol_or_list = symbol_or_list
      @price_overwrite = price_overwrite
      @what_was_buyed = []
      load_item_list
      unless @force_close == true
        @index = @index.clamp(0, @last_index)
        @running = true
      end
    end

    private

    # Launch the process that gets all lists
    def load_item_list
      @item_quantity = []
      get_list_item
      get_definitive_list_price
      check_if_shop_empty
      @index = 0
      @last_index = @list_item.size - 1
    end
    alias reload_item_list load_item_list

    # Create the initial list from symbol_or_list
    def get_list_item
      if @symbol_or_list.is_a? Symbol
        if @shop.shop_list.key?(@symbol_or_list)
          @list_item = @shop.shop_list[@symbol_or_list].keys
          @item_quantity = []
          @list_item.each {|id| @item_quantity << @shop.shop_list[@symbol_or_list][id]}
        else
          raise 'Shop with symbol :' + @symbol_or_list.to_s + ' must be created before calling it'
          @running = false
        end
      elsif @symbol_or_list.is_a? Array
        @list_item = @symbol_or_list
        check_if_shop_empty
      end
      @index = 0
      @last_index = @list_item.size - 1
    end

    # Get the definitive lists by checking the @price_overwrite variable
    def get_definitive_list_price
      arr = []
      temp_list_item = []
      temp_item_quantity = []
      price = 0
      @list_item.each_with_index do |item, index|
        price = @price_overwrite.key?(item) ? @price_overwrite[item] : data_item(item).price
        next if price <= 0
        next if !data_item(item).is_limited && $bag.contain_item?(item)

        arr << price
        temp_list_item << @list_item[index]
        temp_item_quantity << @item_quantity[index] unless @item_quantity.empty?
      end
      @list_item = temp_list_item
      @item_quantity = temp_item_quantity unless @item_quantity.empty?
      @list_price = arr
    end

    # Method that checks if the shop is empty, closing it if that's the case
    def check_if_shop_empty
      if @list_item.empty?
        $game_variables[::Yuki::Var::TMP1] = (@what_was_buyed.empty? ? -1 : 3)
        @force_close = true
        update_mouse(false)
      end
    end
  end
end

GamePlay.shop_class = GamePlay::Shop
