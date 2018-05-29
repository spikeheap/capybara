# frozen_string_literal: true

require 'capybara/selector/filter_set'
require 'capybara/selector/css'

module Capybara
  class Selector
    attr_reader :name, :format
    extend Forwardable

    class << self
      def all
        @selectors ||= {} # rubocop:disable Naming/MemoizedInstanceVariableName
      end

      def add(name, &block)
        all[name.to_sym] = Capybara::Selector.new(name.to_sym, &block)
      end

      def update(name, &block)
        all[name.to_sym].instance_eval(&block)
      end

      def remove(name)
        all.delete(name.to_sym)
      end
    end

    def initialize(name, &block)
      @name = name
      @filter_set = FilterSet.add(name) {}
      @match = nil
      @label = nil
      @failure_message = nil
      @description = nil
      @format = nil
      @expression = nil
      @expression_filters = {}
      @default_visibility = nil
      instance_eval(&block)
    end

    def custom_filters
      warn "Deprecated: #custom_filters is not valid when same named expression and node filter exist - don't use"
      node_filters.merge(expression_filters).freeze
    end

    def node_filters
      @filter_set.node_filters
    end

    def expression_filters
      @filter_set.expression_filters
    end

    ##
    #
    # Define a selector by an xpath expression
    #
    # @overload xpath(*expression_filters, &block)
    #   @param [Array<Symbol>] expression_filters ([])  Names of filters that can be implemented via this expression
    #   @yield [locator, options]                       The block to use to generate the XPath expression
    #   @yieldparam [String] locator                    The locator string passed to the query
    #   @yieldparam [Hash] options                      The options hash passed to the query
    #   @yieldreturn [#to_xpath, #to_s]                 An object that can produce an xpath expression
    #
    # @overload xpath()
    # @return [#call]                             The block that will be called to generate the XPath expression
    #
    def xpath(*allowed_filters, &block)
      if block
        @format, @expression = :xpath, block
        allowed_filters.flatten.each { |ef| expression_filters[ef] = Filters::IdentityExpressionFilter.new }
      end
      format == :xpath ? @expression : nil
    end

    ##
    #
    # Define a selector by a CSS selector
    #
    # @overload css(*expression_filters, &block)
    #   @param [Array<Symbol>] expression_filters ([])  Names of filters that can be implemented via this CSS selector
    #   @yield [locator, options]                   The block to use to generate the CSS selector
    #   @yieldparam [String] locator               The locator string passed to the query
    #   @yieldparam [Hash] options                 The options hash passed to the query
    #   @yieldreturn [#to_s]                        An object that can produce a CSS selector
    #
    # @overload css()
    # @return [#call]                             The block that will be called to generate the CSS selector
    #
    def css(*allowed_filters, &block)
      if block
        @format, @expression = :css, block
        allowed_filters.flatten.each { |ef| expression_filters[ef] = nil }
      end
      format == :css ? @expression : nil
    end

    ##
    #
    # Automatic selector detection
    #
    # @yield [locator]                   This block takes the passed in locator string and returns whether or not it matches the selector
    # @yieldparam [String], locator      The locator string used to determin if it matches the selector
    # @yieldreturn [Boolean]             Whether this selector matches the locator string
    # @return [#call]                    The block that will be used to detect selector match
    #
    def match(&block)
      @match = block if block
      @match
    end

    ##
    #
    # Set/get a descriptive label for the selector
    #
    # @overload label(label)
    #   @param [String] label            A descriptive label for this selector - used in error messages
    # @overload label()
    # @return [String]                 The currently set label
    #
    def label(label = nil)
      @label = label if label
      @label
    end

    ##
    #
    # Description of the selector
    #
    # @param [Hash] options            The options of the query used to generate the description
    # @return [String]                 Description of the selector when used with the options passed
    #

    def_delegator :@filter_set, :description
    def description(**options)
      @filter_set.description(options)
    end

    def call(locator, **options)
      if format
        @expression.call(locator, options)
      else
        warn "Selector has no format"
      end
    end

    ##
    #
    #  Should this selector be used for the passed in locator
    #
    #  This is used by the automatic selector selection mechanism when no selector type is passed to a selector query
    #
    # @param [String] locator     The locator passed to the query
    # @return [Boolean]           Whether or not to use this selector
    #
    def match?(locator)
      @match&.call(locator)
    end

    ##
    #
    # Define a node filter for use with this selector
    #
    # @overload filter(name, *types, options={}, &block)
    #   @param [Symbol, Regexp] name            The filter name
    #   @param [Array<Symbol>] types    The types of the filter - currently valid types are [:boolean]
    #   @param [Hash] options ({})      Options of the filter
    #   @option options [Array<>] :valid_values Valid values for this filter
    #   @option options :default        The default value of the filter (if any)
    #   @option options :skip_if        Value of the filter that will cause it to be skipped
    #   @option options [Regexp] :matcher (nil) A Regexp used to check whether a specific option is handled by this filter.  If not provided the filter will be used for options matching the filter name.
    #
    # If a Symbol is passed for the name the block should accept | node, option_value |, while if a Regexp
    # is passed for the name the block should accept | node, option_name, option_value |. In either case
    # the block should return `true` if the node passes the filer or `false` if it doesn't

    ##
    #
    # Define an expression filter for use with this selector
    #
    # @overload expression_filter(name, *types, options={}, &block)
    #   @param [Symbol, Regexp] name            The filter name
    #   @param [Regexp] matcher (nil)   A Regexp used to check whether a specific option is handled by this filter
    #   @param [Array<Symbol>] types    The types of the filter - currently valid types are [:boolean]
    #   @param [Hash] options ({})      Options of the filter
    #   @option options [Array<>] :valid_values Valid values for this filter
    #   @option options :default        The default value of the filter (if any)
    #   @option options :skip_if        Value of the filter that will cause it to be skipped
    #   @option options [Regexp] :matcher (nil) A Regexp used to check whether a specific option is handled by this filter.  If not provided the filter will be used for options matching the filter name.
    #
    # If a Symbol is passed for the name the block should accept | current_expression, option_value |, while if a Regexp
    # is passed for the name the block should accept | current_expression, option_name, option_value |. In either case
    # the block should return the modified expression

    def_delegators :@filter_set, :node_filter, :expression_filter, :filter

    def filter_set(name, filters_to_use = nil)
      f_set = FilterSet.all[name]
      f_set.expression_filters.each do |n, filter|
        @filter_set.expression_filters[n] = filter if filters_to_use.nil? || filters_to_use.include?(n)
      end
      f_set.node_filters.each do |n, filter|
        @filter_set.node_filters[n] = filter if filters_to_use.nil? || filters_to_use.include?(n)
      end
      f_set.descriptions.each { |desc| @filter_set.describe(&desc) }
    end

    def_delegator :@filter_set, :describe

    ##
    #
    # Set the default visibility mode that shouble be used if no visibile option is passed when using the selector.
    # If not specified will default to the behavior indicated by Capybara.ignore_hidden_elements
    #
    # @param [Symbol] default_visibility  Only find elements with the specified visibility:
    #                                              * :all - finds visible and invisible elements.
    #                                              * :hidden - only finds invisible elements.
    #                                              * :visible - only finds visible elements.
    def visible(default_visibility)
      @default_visibility = default_visibility
    end

    def default_visibility(fallback = Capybara.ignore_hidden_elements)
      if @default_visibility.nil?
        fallback
      else
        @default_visibility
      end
    end

  private

    def locate_field(xpath, locator, enable_aria_label: false, **_options)
      locate_xpath = xpath # Need to save original xpath for the label wrap
      if locator
        locator = locator.to_s
        attr_matchers = [XPath.attr(:id) == locator,
                         XPath.attr(:name) == locator,
                         XPath.attr(:placeholder) == locator,
                         XPath.attr(:id) == XPath.anywhere(:label)[XPath.string.n.is(locator)].attr(:for)].reduce(:|)
        attr_matchers |= XPath.attr(:'aria-label').is(locator) if enable_aria_label

        locate_xpath = locate_xpath[attr_matchers]
        locate_xpath = locate_xpath.union(XPath.descendant(:label)[XPath.string.n.is(locator)].descendant(xpath))
      end

      # locate_xpath = [:name, :placeholder].inject(locate_xpath) { |memo, ef| memo[find_by_attr(ef, options[ef])] }
      locate_xpath
    end

    def describe_all_expression_filters(**opts)
      expression_filters.map do |ef_name, ef|
        if ef.matcher?
          opts.keys.map do |k|
            " with #{ef_name}[#{k} => #{opts[k]}]" if ef.handles_option?(k) && !::Capybara::Queries::SelectorQuery::VALID_KEYS.include?(k)
          end.join
        elsif opts.key?(ef_name)
          " with #{ef_name} #{opts[ef_name]}"
        end
      end.join
    end

    def find_by_attr(attribute, value)
      finder_name = "find_by_#{attribute}_attr"
      if respond_to?(finder_name, true)
        send(finder_name, value)
      else
        value ? XPath.attr(attribute) == value : nil
      end
    end

    def find_by_class_attr(classes)
      Array(classes).map { |klass| XPath.attr(:class).contains_word(klass) }.reduce(:&)
    end
  end
end
