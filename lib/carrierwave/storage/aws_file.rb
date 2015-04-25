module CarrierWave
  module Storage
    class AWSFile
      attr_writer :content_type
      attr_reader :uploader, :connection, :path

      def initialize(uploader, connection, path)
        @uploader   = uploader
        @connection = connection
        @path       = path
      end

      def attributes
        file.head.data
      end

      def content_type
        @content_type || file.content_type
      end

      def delete
        file.delete
      end

      def extension
        path.split('.').last
      end

      def exists?
        file.exists?
      end

      def filename(options = {})
        if file_url = url(options)
          URI.decode(file_url.split('?').first).gsub(/.*\/(.*?$)/, '\1')
        end
      end

      def read
        file.read(uploader_read_options)
      end

      def size
        file.content_length
      end

      def store(new_file)
        file.upload_file(new_file.path, uploader_write_options(new_file))
      end

      def to_file
        file
      end

      def url(options = {})
        if uploader.aws_acl != :public_read
          authenticated_url(options)
        else
          public_url
        end
      end

      def authenticated_url(options = {})
        file.presigned_url(:get, { expires_in: uploader.aws_authenticated_url_expiration }.merge(options)).to_s
      end

      def public_url
        if uploader.asset_host
          "#{uploader.asset_host}/#{path}"
        else
          file.public_url.to_s
        end
      end

      def copy_to(new_path)
        bucket.object(new_path).copy_from(copy_source: file, uploader_copy_options)
      end

      def uploader_read_options
        uploader.aws_read_options || {}
      end

      def uploader_write_options(new_file)
        aws_attributes    = uploader.aws_attributes    || {}
        aws_write_options = uploader.aws_write_options || {}

        { acl:          uploader.aws_acl,
          content_type: new_file.content_type,
        }.merge(aws_attributes).merge(aws_write_options)
      end

      def uploader_copy_options
        aws_write_options = uploader.aws_write_options || {}

        storage_options = aws_write_options.select do |key,_|
          [:reduced_redundancy, :storage_class, :server_side_encryption].include?(key)
        end

        { acl: uploader.aws_acl }.merge(storage_options)
      end

      private
      def resource
        Aws::S3::Resource.new(client: connection)
      end

      def bucket
        @bucket ||= resource.bucket(uploader.aws_bucket)
      end

      def file
        @file ||= bucket.object(path)
      end
    end
  end
end
