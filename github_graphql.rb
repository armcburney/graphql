# frozen_string_literal: true

require 'active_support'
require 'terminal-table'
require 'graphql/client'
require 'graphql/client/http'
require 'open-uri'

HTTPAdapter = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
  def headers(_context)
    { 'Authorization' => "Bearer #{ENV['GITHUB_TOKEN']}" }
  end
end

# Fetch latest schema on init, this will make a network request
Schema = GraphQL::Client.load_schema(HTTPAdapter)
Client = GraphQL::Client.new(schema: Schema, execute: HTTPAdapter)

languages = %w[ruby coffeescript]
locations = %w[san-francisco san-jose berkley oakland san-bruno san-mateo]

location_string = locations.map { |language| "location:#{language}" }.join(' ')
language_string = languages.map { |language| "language:#{language}" }.join(' ')

UserQuery = Client.parse <<-'GRAPHQL'
  query($query_string: String!) {
    search(query: $query_string, type: USER, first: 10) {
      userCount
      edges {
        cursor
        node {
          ... on User {
            id
            name
            email
            company
            url
            isHireable
            websiteUrl
            location
            followers {
              totalCount
            }
            organizations(first: 10) {
              nodes {
                name
                teamsUrl
              }
            }
            repositories(first: 100, orderBy: {field: PUSHED_AT, direction: DESC}) {
              nodes {
                name
                url
                languages(first: 5, orderBy: {field: SIZE, direction:DESC}) {
                  nodes {
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
  }
GRAPHQL

query_variables = {
  query_string: language_string + ' ' + location_string,
  user_limit: 10
}

# Execute the query and parse the result
result = Client.query(UserQuery, variables: query_variables)

a = result.data.search.edges.map do |edge|
  user = edge.node
  {
    cursor: edge.cursor,
    github_id: user.id,
    name: user.name,
    website: user.website_url,
    url: user.url,
    email: user.email,
    company: user.company,
    location: user.location,
    follower_count: user.followers.total_count,
    is_hireable: user.is_hireable,
    organizations: user.organizations.nodes.map(&:name),
    repositories: user.repositories.nodes.map do |repo|
      {
        name: repo.name,
        url: repo.url,
        languages: repo.languages.nodes.map(&:name)
      }
    end
  }
end

puts a
