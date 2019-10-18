Rails.application.routes.draw do
  root 'welcome#index'
  
  post 'auth/login', to: 'authentication#authenticate'
  post 'signup', to: 'users#create'

  resources :documents
  get 'documents/file/:id', to: 'documents#download'
  resources :folders
  get 'folders-all', to: 'folders#all' 
  resources :states
  resources :people
  resources :tags

  get 'search/suggestions/:text', to: 'search#suggestions'
end
