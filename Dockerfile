# Use official PHP Apache image
FROM php:8.2-apache

# Install MySQL PDO extension
RUN docker-php-ext-install pdo pdo_mysql mysqli

# Enable Apache modules
RUN a2enmod rewrite headers

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY htdocs/ /var/www/html/

# Set proper permissions BEFORE configuring Apache
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

# Configure Apache to allow .htaccess overrides
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Add explicit directory configuration
RUN echo '<Directory /var/www/html/>' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '    Options Indexes FollowSymLinks' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '    AllowOverride All' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '    Require all granted' >> /etc/apache2/conf-available/docker-php.conf \
    && echo '</Directory>' >> /etc/apache2/conf-available/docker-php.conf \
    && a2enconf docker-php

# Expose port 80
EXPOSE 80

# Start Apache in foreground
CMD ["apache2-foreground"]
