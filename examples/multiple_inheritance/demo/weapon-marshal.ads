with Giop_C ;
with Corba ;
with Netbufferedstream ;
with Membufferedstream ;
use type Corba.Unsigned_Long; 
package weapon.Marshal is

   procedure Marshall (A : in name ;
                       S : in out Netbufferedstream.Object'Class) ;

   procedure UnMarshall (A : out name ;
                       S : in out Netbufferedstream.Object'Class) ;

   function Align_Size (A : in name ;
                        Initial_Offset : in Corba.Unsigned_Long ;
                        N : in Corba.Unsigned_Long := 1)
                        return Corba.Unsigned_Long ;


   procedure Marshall (A : in dist ;
                       S : in out Netbufferedstream.Object'Class) ;

   procedure UnMarshall (A : out dist ;
                         S : in out Netbufferedstream.Object'Class) ;

   function Align_Size (A : in dist ;
                        Initial_Offset : in Corba.Unsigned_Long ;
                        N : in Corba.Unsigned_Long := 1)
                        return Corba.Unsigned_Long ;


end weapon.Marshal ;
