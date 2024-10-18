set app_image_repository_schema = $app_database || '.image_repository_schema';
set app_image_repository_stage = $app_image_repository_schema || '.image_repository_stage';


use database snowflake; --exists for all roles
use role identifier($app_role);
use warehouse identifier($app_warehouse);


-- create objects needed for deployment of the docker image 
create database if not exists identifier($app_database);

create schema if not exists identifier($app_image_repository_schema);

create image repository if not exists identifier($app_image_repository_stage);
