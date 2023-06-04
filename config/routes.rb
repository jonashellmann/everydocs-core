Rails.application.routes.draw do
  root 'welcome#index'
  
  post 'auth/login', to: 'authentication#authenticate'
  post 'signup', to: 'users#create'

  get 'documents/file/:id', to: 'documents#download'
  get 'documents/pages', to: 'documents#page_count'
  resources :documents

  resources :folders
  get 'folders-all', to: 'folders#all' 

  resources :states
  resources :people
  resources :tags

  get 'search/suggestions/:text', to: 'search#suggestions'
  get 'version', to: 'version#version'
end
