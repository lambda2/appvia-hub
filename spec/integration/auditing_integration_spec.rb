require 'rails_helper'

RSpec.describe 'Auditing integration' do
  include_context 'time helpers'

  before do
    @user = create :user
    @app = create :app
  end

  it 'has one create audit for the User' do
    expect(@user.audits.count).to be 1
    audit = @user.audits.first
    expect(audit.action).to eq 'create'
    expect(audit.created_at.to_i).to eq now.to_i
  end

  it 'has one create audit for the App' do
    expect(@app.audits.count).to be 1
    audit = @app.audits.first
    expect(audit.action).to eq 'create'
    expect(audit.created_at.to_i).to eq now.to_i
  end

  it 'cannot update an existing audit' do
    audit = Audit.first
    expect do
      audit.comment = 'fooooo'
      audit.save!
    end.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'cannot destroy an existing audit' do
    expect do
      Audit.first.destroy
    end.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'can create a new Audit record as expected' do
    action = 'hammertime'
    comment = 'hammertime is now'

    expect do
      audit = Audit.create(
        action: action,
        auditable: @app,
        user: @user,
        comment: comment
      )

      persisted = Audit.find audit.id
      expect(persisted.action).to eq action
      expect(persisted.auditable).to eq @app
      expect(persisted.auditable_descriptor).to eq @app.slug
      expect(persisted.user).to eq @user
      expect(persisted.user_email).to eq @user.email
      expect(persisted.comment).to eq comment
      expect(persisted.created_at.to_i).to eq now.to_i
    end.to change { Audit.count }.by(1)
  end
end
