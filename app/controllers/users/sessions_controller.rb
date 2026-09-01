module Users
  class SessionsController < Devise::SessionsController
    # Head-to-Head identifies a player by its own signed cookie
    # (`HeadToHeadController::SESSION_COOKIE`, 1 year) so a guest's in-flight
    # game survives a page reload and can be claimed at signup. That cookie is
    # deliberately independent of the Devise session — which means signing out
    # left it behind, and the next visitor on the device hit "Head to Head" and
    # was redirected straight to the previous person's finished ranking,
    # complete with "+50 added to your fantasy portfolio" for a portfolio they
    # do not have.
    #
    # Signing out ends the game too.
    def destroy
      cookies.delete(HeadToHeadController::SESSION_COOKIE)
      super
    end
  end
end
