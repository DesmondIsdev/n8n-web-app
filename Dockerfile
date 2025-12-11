# Use official PHP Apache image
FROM php:8.2-apache

# Install MySQL PDO extension
RUN docker-php-ext-install pdo pdo_mysql mysqli

# Enable Apache modules
RUN a2enmod rewrite headers

# Set ServerName to suppress warning
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Set working directory
WORKDIR /var/www/html

# Remove default Apache index
RUN rm -f /var/www/html/index.html

# Copy application files explicitly
COPY --chown=www-data:www-data htdocs/*.php /var/www/html/
COPY --chown=www-data:www-data htdocs/*.html /var/www/html/
COPY --chown=www-data:www-data htdocs/.htaccess /var/www/html/
COPY --chown=www-data:www-data htdocs/api/ /var/www/html/api/

# Set proper permissions
RUN find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

# List files for debugging
RUN echo "=== Files in /var/www/html ===" \
    && ls -la /var/www/html/ \
    && echo "=== End of file listing ==="

# Configure Apache to allow .htaccess overrides
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Add explicit directory configuration
RUN echo '<Directory /var/www/html/>' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '    Options -Indexes +FollowSymLinks' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '    AllowOverride All' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '    Require all granted' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '    DirectoryIndex index.php index.html index2.html' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '</Directory>' >> /etc/apache2/conf-available/docker-php.conf \
    && a2enconf docker-php

# Expose port 80
EXPOSE 80

# Start Apache in foreground
CMD ["apache2-foreground"]
