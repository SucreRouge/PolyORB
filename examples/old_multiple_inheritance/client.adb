----                                                                    ----
----     This in an example which is hand-written                       ----
----                                                                    ----
----             procedure client                                       ----
----                                                                    ----
----     author : Sebastien Ponce, Fabien Azavant                       ----
----                                                                    ----
----------------------------------------------------------------------------

with Corba.Object ; use Corba.Object ;
with Weapon ;
with Vehicle ;
with Tank ;

use Tank ;

with Text_IO ; use Text_IO ;


procedure Client is


   -----------------------------------------------
   ----        To test everything             ----
   -----------------------------------------------
   procedure Global_Test is
      W : Weapon.Ref ;
      V : Vehicle.Ref ;
      T : Tank.Ref ;
      O : Corba.Object.Ref ;
      TT : Tank.Weapon_Ref := To_Ref(T) ;
   begin

      Put_Line(">>>>>>>> Test program for To_Ref <<<<<<<<<<<<") ;
      Put_Line("") ;

      Put_Line("--- Trying to cast Weapon.Ref into Corba.Object.Ref") ;
      O := To_Ref(W) ;
      Put_Line(">>> cast succeeded") ;
      Put_Line("") ;

      Put_Line("--- Trying to cast Tank.Ref into Corba.Object.Ref") ;
      O := To_Ref(T) ;
      Put_Line(">>> cast succeeded") ;
      Put_Line("") ;

      Put_Line("--- Trying to cast Tank.Ref into Vehicle.Ref") ;
      V := Vehicle.To_Ref(T) ;
      Put_Line(">>> cast succeeded") ;
      Put_Line("") ;

      Put_Line("--- Trying to cast Tank.Ref into Weapon.Ref") ;
      W := Weapon.To_Ref(T) ;
      Put_Line(">>> cast succeeded") ;
      Put_Line("") ;

      Put_Line("--- Trying to cast Tank.Ref_Weapon into Weapon.Ref") ;
      W := Weapon.To_Ref(Tt) ;
      Put_Line(">>> cast succeeded") ;
      Put_Line("") ;

      Put_Line("--- Trying to cast Tank.Ref_Weapon into Vehicle.Ref") ;
      V := Vehicle.To_Ref(Tt) ;
      Put_Line(">>> cast succeeded");
      Put_Line("") ;

      Put_Line("Everything works all right !!") ;

   end Global_Test ;

   -----------------------------------------------
   ----        To test a few things           ----
   -----------------------------------------------
   procedure Simple_Test is
      T : Tank.Ref ;
      Tt : Tank.Weapon_Ref ;
   begin
      Tt := To_Ref(T) ;
      Put_Line("Running the simple test") ;
   end Simple_Test ;

begin
   -- Simple_Test ;
   Global_Test ;
end Client ;



