module Koala
  module Facebook
    GRAPH_SERVER = "graph.facebook.com"   

    module GraphAPIMethods
      # A client for the Facebook Graph API.
      # 
      # See http://github.com/arsduo/koala for Ruby/Koala documentation
      # and http://developers.facebook.com/docs/api for Facebook API documentation
      # 
      # The Graph API is made up of the objects in Facebook (e.g., people, pages,
      # events, photos) and the connections between them (e.g., friends,
      # photo tags, and event RSVPs). This client provides access to those
      # primitive types in a generic way. For example, given an OAuth access
      # token, this will fetch the profile of the active user and the list
      # of the user's friends:
      # 
      #    graph = Koala::Facebook::GraphAPI.new(access_token)
      #    user = graph.get_object("me")
      #    friends = graph.get_connections(user["id"], "friends")
      # 
      # You can see a list of all of the objects and connections supported
      # by the API at http://developers.facebook.com/docs/reference/api/.
      # 
      # You can obtain an access token via OAuth or by using the Facebook
      # JavaScript SDK. See the Koala and Facebook documentation for more information.
      # 
      # If you are using the JavaScript SDK, you can use the
      # Koala::Facebook::OAuth.get_user_from_cookie() method below to get the OAuth access token
      # for the active user from the cookie saved by the SDK.
         
      # Objects

      def get_object(id, args = {})
        # Fetchs the given object from the graph.
        graph_call(id, args)
      end
    
      def get_objects(ids, args = {})
        # Fetchs all of the given object from the graph.
        # We return a map from ID to object. If any of the IDs are invalid,
        # we raise an exception.
        graph_call("", args.merge("ids" => ids.join(",")))
      end
      
      def put_object(parent_object, connection_name, args = {})
        # Writes the given object to the graph, connected to the given parent.
        # See http://developers.facebook.com/docs/api#publishing for all of
        # the supported writeable objects.
        # 
        # For example,
        #     graph.put_object("me", "feed", :message => "Hello, world")
        # writes "Hello, world" to the active user's wall.
        #
        # Most write operations require extended permissions. For example,
        # publishing wall posts requires the "publish_stream" permission. See
        # http://developers.facebook.com/docs/authentication/ for details about
        # extended permissions.
    
        raise APIError.new({"type" => "KoalaMissingAccessToken", "message" => "Write operations require an access token"}) unless @access_token
        graph_call("#{parent_object}/#{connection_name}", args, "post")
      end
      
      def delete_object(id)
        # Deletes the object with the given ID from the graph.
        raise APIError.new({"type" => "KoalaMissingAccessToken", "message" => "Delete requires an access token"}) unless @access_token
        graph_call(id, {}, "delete")
      end
      
      # Connections
          
      def get_connections(id, connection_name, args = {})
        # Fetchs the connections for given object.
        result = graph_call("#{id}/#{connection_name}", args)
        result ? GraphCollection.new(result, self) : nil # when facebook is down nil can be returned
      end

      def put_connections(id, connection_name, args = {})
        # Posts a certain connection
        raise APIError.new({"type" => "KoalaMissingAccessToken", "message" => "Write operations require an access token"}) unless @access_token
        graph_call("#{id}/#{connection_name}", args, "post")
      end

      def delete_connections(id, connection_name, args = {})
        # Deletes a given connection
        raise APIError.new({"type" => "KoalaMissingAccessToken", "message" => "Delete requires an access token"}) unless @access_token
        graph_call("#{id}/#{connection_name}", args, "delete")
      end

      # Pictures
      # to delete pictures, use delete_object(photo_id)
      # note: you'll need the user_photos permission to actually access photos after uploading them 
    
      def get_picture(object, args = {})
        # Gets a picture object, returning the URL (which Facebook sends as a header)
        result = graph_call("#{object}/picture", args, "get", :http_component => :headers)
        result["Location"]
      end    
    
      def put_picture(io_or_path, content_type, args = {}, target_id = "me")
        # Uploads a picture from a file hash
        args["source"] = Koala::UploadableIO.new(io_or_path, content_type)
        
        self.put_object(target_id, "photos", args)
      end
    
      # Wall posts
      # To get wall posts, use get_connections(user, "feed")
      # To delete a wall post, just use delete_object(post_id)
    
      def put_wall_post(message, attachment = {}, profile_id = "me")
        # attachment is a hash describing the wall post
        # (see X for more details)
        # For instance, 
        # 
        #     {"name" => "Link name"
        #      "link" => "http://www.example.com/",
        #      "caption" => "{*actor*} posted a new review",
        #      "description" => "This is a longer description of the attachment",
        #      "picture" => "http://www.example.com/thumbnail.jpg"}

        self.put_object(profile_id, "feed", attachment.merge({:message => message}))
      end
      
      # Comments
      # to delete comments, use delete_object(comment_id)
      # to get comments, use get_connections(object, "likes")
      
      def put_comment(object_id, message)
        # Writes the given comment on the given post.
        self.put_object(object_id, "comments", {:message => message})
      end
        
      # Likes
      # to get likes, use get_connections(user, "likes")
      
      def put_like(object_id)
        # Likes the given post.
        self.put_object(object_id, "likes")
      end

      def delete_like(object_id)
        # Unlikes a given object for the logged-in user
        raise APIError.new({"type" => "KoalaMissingAccessToken", "message" => "Unliking requires an access token"}) unless @access_token
        graph_call("#{object_id}/likes", {}, "delete")
      end

      # Search
      
      def search(search_terms, args = {})
        # Searches for a given term among posts visible to the current user (or public posts if no token)
        result = graph_call("search", args.merge({:q => search_terms}))
        result ? GraphCollection.new(result, self) : nil # when facebook is down nil can be returned
      end      
      
      # API access
    
      def graph_call(*args)
        # Direct access to the Facebook API
        # see any of the above methods for example invocations
        response = api(*args) do |response|
          # check for Graph API-specific errors
          if response.is_a?(Hash) && error_details = response["error"]
            raise APIError.new(error_details)
          end
        end
      
        response
      end 
      
      # GraphCollection support
      
      def get_page(params)
        # Pages through a set of results stored in a GraphCollection
        # Used for connections and search results
        result = graph_call(*params)
        result ? GraphCollection.new(result, self) : nil # when facebook is down nil can be returned
      end
      
    end
    
    
    class GraphCollection < Array
      #This class is a light wrapper for collections returned
      #from the Graph API.
      #
      #It extends Array to allow direct access to the data colleciton
      #which should allow it to drop in seamlessly.
      #
      #It also allows access to paging information and the
      #ability to get the next/previous page in the collection
      #by calling next_page or previous_page.
      attr_reader :paging
      attr_reader :api
      
      def initialize(response, api)
        super response["data"]
        @paging = response["paging"]
        @api = api
      end
            
      # defines methods for NEXT and PREVIOUS pages
      %w{next previous}.each do |this|
        
        # def next_page
        # def previous_page
        define_method "#{this.to_sym}_page" do
          base, args = send("#{this}_page_params")
          base ? @api.get_page([base, args]) : nil
        end
        
        # def next_page_params
        # def previous_page_params
        define_method "#{this.to_sym}_page_params" do
          return nil unless @paging and @paging[this]
          parse_page_url(@paging[this])
        end
      end
      
      def parse_page_url(url)
        match = url.match(/.com\/(.*)\?(.*)/)
        base = match[1]
        args = match[2]
        params = CGI.parse(args)
        new_params = {}
        params.each_pair do |key,value|
          new_params[key] = value.join ","
        end
        [base,new_params]
      end
      
    end
  end
end
