

Rails.application.routes.draw do
  root "phone_numbers#index"

  resources :phone_numbers do
    collection do
      post :bulk_upload
      post :call_all
      post :ai_prompt
    end
    member do
      post :call_now
    end
  end

  resource :scrape, only: [:show, :create] do
    get :download
  end

  scope :blog do
    get    "/"         => "blog#index",    as: :blog
    post   "/generate" => "blog#generate", as: :generate_blog
    get    "/:slug"    => "blog#show",     as: :blog_post
    delete "/:slug"    => "blog#destroy",  as: :delete_blog_post

  end
end

