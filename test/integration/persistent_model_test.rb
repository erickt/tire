require 'test_helper'

module Tire

  class PersistentModelIntegrationTest < Test::Unit::TestCase
    include Test::Integration

    def setup
      super
      PersistentArticle.index.delete
    end

    def teardown
      super
      PersistentArticle.index.delete
      PersistentArticleWithDefaults.index.delete
    end

    context "PersistentModel" do
      should "cast results returned from ElasticSearch" do
        time = Time.at(0)

        article1 = PersistentArticleWithCastedItem.create :id => 1,
                                                          :title => 'One',
                                                          :count => '1',
                                                          :boost => '1.5',
                                                          :created_at => time.to_s,
                                                          :updated_at => 0
        article2 = PersistentArticleWithCastedItem.find 1

        assert_equal 'persistent_article_with_casted_items', article2._index
        assert_equal 'persistent_article_with_casted_item', article2._type
        assert_equal article1._version, article2._version
        assert_equal '1', article2.id
        assert_equal 'One', article2.title
        assert_equal 1, article2.count
        assert_equal 1.5, article2.boost
        assert_equal time, article2.created_at
        assert_equal time, article2.updated_at
      end

      should "search with simple query" do
        PersistentArticle.create :id => 1, :title => 'One'
        PersistentArticle.index.refresh

        results = PersistentArticle.search 'one'
        assert_equal 'One', results.first.title
      end

      should "search with a block" do
        PersistentArticle.create :id => 1, :title => 'One'
        PersistentArticle.index.refresh

        results = PersistentArticle.search(:sort => 'title') { query { string 'one' } }
        assert_equal 'One', results.first.title
      end

      should "return instances of model" do
        PersistentArticle.create :id => 1, :title => 'One'
        PersistentArticle.index.refresh

        results = PersistentArticle.search 'one'
        assert_instance_of PersistentArticle, results.first
      end

      should "save documents into index and find them by IDs" do
        one = PersistentArticle.create :id => 1, :title => 'One'
        two = PersistentArticle.create :id => 2, :title => 'Two'

        PersistentArticle.index.refresh

        results = PersistentArticle.find [1, 2]

        assert_equal 2, results.size

      end

      should "return default values for properties without value" do
        PersistentArticleWithDefaults.create :id => 1, :title => 'One'
        PersistentArticleWithDefaults.index.refresh

        results = PersistentArticleWithDefaults.all

        assert_equal [], results.first.tags
      end

      should "update the _version property when saving" do
        article = PersistentArticle.create :id => 1, :title => 'One'
        assert_equal 1, article._version

        assert article.save

        assert_equal 2, article._version
      end

      should "not update with save if there is a version conflict" do
        article = PersistentArticle.create :id => 1, :title => 'One'
        assert article.save
        assert_equal 2, article._version

        article._version = 1

        assert !article.save
      end

      should "not update with save! if there is a version conflict" do
        article = PersistentArticle.create :id => 1, :title => 'One'
        assert article.save
        assert_equal 2, article._version

        article._version = 1

        assert_raise(Tire::RequestError) { article.save! }
      end
      context "with pagination" do

        setup do
          1.upto(9) { |number| PersistentArticle.create :title => "Test#{number}" }
          PersistentArticle.index.refresh
        end

        should "find first page with five results" do
          results = PersistentArticle.search( :per_page => 5, :page => 1 ) { query { all } }
          assert_equal 5, results.size

          # WillPaginate
          #
          assert_equal 2, results.total_pages
          assert_equal 1, results.current_page
          assert_equal nil, results.previous_page
          assert_equal 2, results.next_page

          # Kaminari
          #
          assert_equal 5, results.limit_value
          assert_equal 9, results.total_count
          assert_equal 2, results.num_pages
          assert_equal 0, results.offset_value
        end

      end

      context "with namespaced models" do
        setup do
          MyNamespace::PersistentArticleInNamespace.create :title => 'Test'
          MyNamespace::PersistentArticleInNamespace.index.refresh
        end

        teardown do
          MyNamespace::PersistentArticleInNamespace.index.delete
        end

        should "find the document in the index" do
          results = MyNamespace::PersistentArticleInNamespace.search 'test'

          assert       results.any?, "No results returned: #{results.inspect}"
          assert_equal 1, results.count

          assert_instance_of MyNamespace::PersistentArticleInNamespace, results.first
        end

      end

    end

  end
end
